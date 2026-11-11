import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomio/core/firebase/fcm_service.dart';
import 'package:roomio/core/network/app_interceptor.dart';
import 'package:roomio/core/storage/secure_storage_service.dart';
import 'package:roomio/features/notification/application/notification_device_sync.dart';
import 'package:roomio/features/notification/data/data_sources/remote/device_api_service.dart';
import 'package:roomio/features/notification/data/data_sources/remote/notification_api_service.dart';
import 'package:roomio/features/notification/data/repository/notification_repository_impl.dart';
import 'package:roomio/features/notification/domain/usecases/register_device.dart';
import 'package:roomio/features/notification/domain/usecases/unregister_device.dart';
import 'package:roomio/features/notification/domain/usecases/update_device.dart';

import '../chat/chat_test_support.dart' show sessionToken;

void main() {
  const storage = FlutterSecureStorage();
  const deviceKey = 'fcm_device_id:account-1';
  final jwt = sessionToken('account-1');
  late _FakeFcm fcm;
  late Dio dio;
  late NotificationRepositoryImpl repository;
  late NotificationDeviceSync devices;
  late List<RequestOptions> requests;
  late FutureOr<Response<dynamic>> Function(RequestOptions) respond;

  NotificationDeviceSync createSync() => NotificationDeviceSync(
    fcm,
    storage,
    RegisterDeviceUseCase(repository),
    UpdateDeviceUseCase(repository),
    UnregisterDeviceUseCase(repository),
  );

  Response<dynamic> response(RequestOptions options) => Response(
    requestOptions: options,
    statusCode: 200,
    data: options.method == 'POST'
        ? {'id_device': 'device-1'}
        : {'message': 'Success'},
  );

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'access_token': jwt});
    fcm = _FakeFcm();
    requests = [];
    respond = response;
    dio = Dio()
      ..interceptors.addAll([
        AppInterceptor(SecureStorageService(storage), onUnauthorized: () {}),
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            requests.add(options);
            final result = await respond(options);
            if (result.statusCode! >= 400) {
              handler.reject(
                DioException.badResponse(
                  statusCode: result.statusCode!,
                  requestOptions: options,
                  response: result,
                ),
              );
            } else {
              handler.resolve(result);
            }
          },
        ),
      ]);
    repository = NotificationRepositoryImpl(
      NotificationlApiService(dio),
      DeviceApiService(dio),
    );
  });

  tearDown(() async {
    await devices.dispose();
    await fcm.refresh.close();
    dio.close();
  });

  test(
    'login registers once and restored session patches the saved device',
    () async {
      devices = createSync();
      devices.startSession(jwt);
      devices.startSession(jwt);
      await pumpEventQueue();

      expect(requests.single.method, 'POST');
      expect(requests.single.uri.path, '/devices/');
      expect(requests.single.data, {
        'fcm_token': 'token-1',
        'platform': 'android',
      });
      expect(await storage.read(key: deviceKey), 'device-1');

      await devices.dispose();
      devices = createSync()..startSession(jwt);
      await pumpEventQueue();
      expect(requests.map((request) => request.method), ['POST', 'PATCH']);
      expect(requests.last.uri.path, '/devices/device-1');
      expect(requests.last.data, {'fcm_token': 'token-1'});
    },
  );

  test(
    'refresh only re-registers when the API reports a missing device',
    () async {
      devices = createSync();
      await storage.write(key: deviceKey, value: 'old-device');
      devices.startSession(jwt);
      await pumpEventQueue();
      respond = (options) => options.method == 'PATCH'
          ? Response(
              requestOptions: options,
              statusCode: 404,
              data: {'detail': 'not found devices'},
            )
          : response(options);

      fcm.refresh.add('token-2');
      await pumpEventQueue();
      fcm.refresh.add('token-2');
      await pumpEventQueue();

      expect(requests.map((request) => request.method), [
        'PATCH',
        'PATCH',
        'POST',
      ]);
      expect(requests[1].uri.path, '/devices/old-device');
      expect(requests.last.data, {
        'fcm_token': 'token-2',
        'platform': 'android',
      });
      expect(await storage.read(key: deviceKey), 'device-1');
    },
  );

  test('a route-level 404 does not trigger another POST', () async {
    devices = createSync();
    await storage.write(key: deviceKey, value: 'old-device');
    respond = (options) => Response(
      requestOptions: options,
      statusCode: 404,
      data: {'detail': 'Not Found'},
    );
    devices.startSession(jwt);
    await pumpEventQueue();
    expect(requests.single.method, 'PATCH');
    expect(await storage.read(key: deviceKey), 'old-device');
  });

  test(
    'logout waits for in-flight registration and ignores later refreshes',
    () async {
      devices = createSync();
      final started = Completer<void>();
      final finish = Completer<void>();
      respond = (options) async {
        if (options.method == 'POST') {
          started.complete();
          await finish.future;
        }
        return response(options);
      };
      devices.startSession(jwt);
      await started.future;
      final logout = devices.unregisterSession();
      fcm.refresh.add('token-after-logout');
      finish.complete();
      await logout;

      expect(requests.map((request) => request.method), ['POST', 'DELETE']);
      expect(requests.last.uri.path, '/devices/device-1');
      expect(requests.last.headers['Authorization'], 'Bearer $jwt');
      expect(await storage.read(key: deviceKey), isNull);
      expect(fcm.deletedTokens, 0);
    },
  );

  test(
    'failed unregister revokes the token and keeps the account device ID',
    () async {
      devices = createSync();
      await storage.write(key: deviceKey, value: 'old-device');
      respond = (options) => options.method == 'DELETE'
          ? Response(requestOptions: options, statusCode: 503)
          : response(options);
      devices.startSession(jwt);
      await pumpEventQueue();
      await devices.unregisterSession();

      expect(requests.map((request) => request.method), ['PATCH', 'DELETE']);
      expect(fcm.deletedTokens, 1);
      expect(fcm.clearedNotifications, 1);
      expect(await storage.read(key: deviceKey), 'old-device');
      expect(devices.session, isNull);
    },
  );
}

class _FakeFcm extends FcmService {
  final refresh = StreamController<String>.broadcast(sync: true);
  int deletedTokens = 0;
  int clearedNotifications = 0;

  @override
  bool get isAvailable => true;

  @override
  Stream<String> get tokenRefresh => refresh.stream;

  @override
  Future<String?> getToken() async => 'token-1';

  @override
  Future<void> deleteToken() async {
    deletedTokens++;
  }

  @override
  Future<void> clearNotifications() async {
    clearedNotifications++;
  }
}
