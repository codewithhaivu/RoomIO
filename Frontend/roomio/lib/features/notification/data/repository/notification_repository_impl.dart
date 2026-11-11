import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/notification/data/data_sources/remote/device_api_service.dart';
import 'package:roomio/features/notification/data/data_sources/remote/notification_api_service.dart';
import 'package:roomio/features/notification/data/models/notification.dart';
import 'package:roomio/features/notification/domain/entities/notification.dart';
import 'package:roomio/features/notification/domain/repository/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationlApiService _api;
  final DeviceApiService _deviceApi;
  NotificationRepositoryImpl(this._api, this._deviceApi);

  Future<DataState<T>> _request<R, T>(
    Future<HttpResponse<R>> Function() request,
    T Function(R) convert, {
    String path = '/notifications/',
    String invalidResponse = 'Dữ liệu thông báo không hợp lệ.',
  }) async {
    try {
      final response = await request();
      final status = response.response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw DioException.badResponse(
          statusCode: status,
          requestOptions: response.response.requestOptions,
          response: response.response,
        );
      }
      return DataSuccess(convert(response.data));
    } on DioException catch (error) {
      return DataError(error);
    } catch (error) {
      return DataError(
        DioException(
          requestOptions: RequestOptions(path: path),
          error: error,
          message: invalidResponse,
        ),
      );
    }
  }

  @override
  Future<DataState<List<NotificationResponse>>> getNotifications(int page) {
    if (page < 1) {
      return Future.value(
        DataError(
          DioException(
            requestOptions: RequestOptions(path: '/notifications/'),
            message: 'Số trang phải lớn hơn hoặc bằng 1.',
          ),
        ),
      );
    }
    return _request(() => _api.getNotifications(page), (result) => result.data);
  }

  @override
  Future<DataState<String>> markNotifications(String notificationId) =>
      _request(
        () => _api.markNotification(notificationId),
        (result) => result.message,
      );

  @override
  Future<DataState<String>> registerDevice(String fcmToken, String platform) =>
      _request(
        () => _deviceApi.registerDevice(
          RegisterDeviceRequest(fcmToken: fcmToken, platform: platform),
        ),
        (result) => result.idDevice,
        path: '/devices/',
        invalidResponse: 'Dữ liệu thiết bị không hợp lệ.',
      );

  @override
  Future<DataState<String>> unregisterDevice(String idDevice) => _request(
    () => _deviceApi.unregisterDevice(idDevice),
    (result) => result.message,
    path: '/devices/$idDevice',
    invalidResponse: 'Dữ liệu thiết bị không hợp lệ.',
  );

  @override
  Future<DataState<String>> updateDevice(String fcmToken, String idDevice) =>
      _request(
        () => _deviceApi.updateDevice(
          idDevice,
          UpdateDeviceRequest(fcmToken: fcmToken),
        ),
        (result) => result.message,
        path: '/devices/$idDevice',
        invalidResponse: 'Dữ liệu thiết bị không hợp lệ.',
      );
}
