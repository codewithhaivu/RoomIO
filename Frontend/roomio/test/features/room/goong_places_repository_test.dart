import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/room/data/data_sources/remote/goong_places_api_service.dart';
import 'package:roomio/features/room/data/repository/room_places_repository_impl.dart';
import 'package:roomio/features/room/domain/entities/room_place_suggestion.dart';
import 'goong_test_data.dart';
import 'room_test_support.dart';

void main() {
  late Dio dio;
  late RoomPlacesRepositoryImpl repository;
  final requests = <RequestOptions>[];
  Object? payload;
  var status = 200;
  DioExceptionType? networkFailure;

  setUp(() {
    requests.clear();
    status = 200;
    networkFailure = null;
    payload = goongAutocompleteJson;
    dio = Dio(BaseOptions(baseUrl: 'https://rsapi.goong.io/'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          if (networkFailure != null) {
            handler.reject(
              DioException(requestOptions: options, type: networkFailure!),
            );
            return;
          }
          final response = Response<dynamic>(
            requestOptions: options,
            data: payload,
            statusCode: status,
          );
          if (status >= 400) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: response,
                type: DioExceptionType.badResponse,
              ),
            );
          } else {
            handler.resolve(response);
          }
        },
      ),
    );
    repository = RoomPlacesRepositoryImpl(
      GoongPlacesApiService(dio: dio, apiKey: 'test-goong-key'),
    );
  });
  tearDown(() => dio.close(force: true));

  Matcher issue(RoomPlacesIssue expected) => throwsA(
    isA<RoomPlacesException>().having(
      (error) => error.issue,
      'issue',
      expected,
    ),
  );

  test('autocomplete uses Goong V2 GET and maps predictions', () async {
    final suggestions = await repository.autocomplete('  Võ Văn  ');
    expect(suggestions.single.placeId, 'goong-place-id');
    expect(suggestions.single.description, goongAddress);
    final request = requests.single;
    expect(request.method, 'GET');
    expect(request.uri.host, 'rsapi.goong.io');
    expect(request.uri.path, '/v2/place/autocomplete');
    expect(request.queryParameters, {
      'api_key': 'test-goong-key',
      'input': 'Võ Văn',
      'limit': 5,
    });
    expect(request.headers['Authorization'], isNull);
    expect(request.data, isNull);
  });

  test('under three trimmed characters never sends a request', () async {
    for (final query in ['', ' ', 'a', 'ab', '  ab  ']) {
      expect(await repository.autocomplete(query), isEmpty);
    }
    expect(requests, isEmpty);
  });

  test('keeps at most five valid suggestions', () async {
    payload = {
      'status': 'OK',
      'predictions': [
        null,
        {'description': 'Missing ID'},
        {'place_id': ' ', 'description': 'Empty ID'},
        {'place_id': 'blank-text', 'description': ' '},
        ...List.generate(
          8,
          (i) => {'place_id': 'id-$i', 'description': 'Địa chỉ $i'},
        ),
      ],
    };
    final suggestions = await repository.autocomplete('Địa chỉ');
    expect(suggestions.map((item) => item.placeId), [
      'id-0',
      'id-1',
      'id-2',
      'id-3',
      'id-4',
    ]);
  });

  test('empty OK and ZERO_RESULTS return empty suggestions', () async {
    for (final response in [
      {'status': 'OK', 'predictions': <dynamic>[]},
      {'status': 'ZERO_RESULTS'},
    ]) {
      payload = response;
      expect(await repository.autocomplete('Không có địa chỉ'), isEmpty);
    }
  });

  test(
    'Place Detail V2 maps geometry lat/lng to backend location fields',
    () async {
      payload = goongDetailJson;
      final selected = await repository.resolvePlace('id+with/slash=');
      expect(selected.name, goongAddress);
      expect(selected.latitude, 10.85);
      expect(selected.longitude, 106.75);
      expect(requests.single.uri.path, '/v2/place/detail');
      expect(requests.single.uri.queryParameters['place_id'], 'id+with/slash=');
      expect(requests.single.queryParameters['api_key'], 'test-goong-key');
    },
  );

  test('missing key fails before networking for both operations', () async {
    final missing = RoomPlacesRepositoryImpl(
      GoongPlacesApiService(dio: dio, apiKey: ' '),
    );
    await expectLater(
      missing.autocomplete('Võ Văn'),
      issue(RoomPlacesIssue.configuration),
    );
    await expectLater(
      missing.resolvePlace('id'),
      issue(RoomPlacesIssue.configuration),
    );
    expect(requests, isEmpty);
  });

  test('HTTP errors become recoverable domain errors', () async {
    for (final code in [401, 403, 429, 500]) {
      status = code;
      payload = {'error': 'service failure'};
      await expectLater(
        repository.autocomplete('Võ Văn'),
        issue(
          code == 401 || code == 403
              ? RoomPlacesIssue.denied
              : RoomPlacesIssue.unavailable,
        ),
      );
    }
  });

  test('API errors in HTTP 200 are not mistaken for empty success', () async {
    for (final apiStatus in [
      'REQUEST_DENIED',
      'PERMISSION_DENIED',
      'INVALID_API_KEY',
      'OVER_QUERY_LIMIT',
      'UNKNOWN_ERROR',
    ]) {
      payload = {'status': apiStatus};
      final expected =
          apiStatus.contains('DENIED') || apiStatus == 'INVALID_API_KEY'
          ? RoomPlacesIssue.denied
          : RoomPlacesIssue.unavailable;
      await expectLater(repository.autocomplete('Võ Văn'), issue(expected));
      await expectLater(repository.resolvePlace('id'), issue(expected));
    }
  });

  test(
    'connection failures and timeouts become recoverable domain errors',
    () async {
      for (final failure in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.connectionError,
      ]) {
        networkFailure = failure;
        await expectLater(
          repository.autocomplete('Võ Văn'),
          issue(
            failure == DioExceptionType.connectionError
                ? RoomPlacesIssue.unavailable
                : RoomPlacesIssue.timeout,
          ),
        );
      }
    },
  );

  test('malformed responses do not escape as runtime exceptions', () async {
    for (final response in [
      null,
      <String, dynamic>{},
      {'status': 'OK'},
      {'status': 'OK', 'predictions': 'invalid'},
    ]) {
      payload = response;
      await expectLater(
        repository.autocomplete('Võ Văn'),
        issue(RoomPlacesIssue.unavailable),
      );
    }
  });

  test(
    'missing or invalid detail coordinates never become a location',
    () async {
      for (final coordinates in [
        null,
        {'lat': 91, 'lng': 106.75},
        {'lat': 10.85, 'lng': 181},
        {'lat': double.nan, 'lng': 106.75},
        {'lat': 10.85, 'lng': double.infinity},
      ]) {
        payload = {
          'status': 'OK',
          'result': {
            'formatted_address': goongAddress,
            'geometry': {'location': coordinates},
          },
        };
        await expectLater(
          repository.resolvePlace('id'),
          issue(RoomPlacesIssue.notFound),
        );
      }
      payload = {'status': 'ZERO_RESULTS'};
      await expectLater(
        repository.resolvePlace('id'),
        issue(RoomPlacesIssue.notFound),
      );
      payload = {'status': 'OK', 'result': null};
      await expectLater(
        repository.resolvePlace('id'),
        issue(RoomPlacesIssue.notFound),
      );
    },
  );

  test(
    'Goong location survives existing backend POST and PATCH serialization',
    () async {
      payload = goongDetailJson;
      final selected = await repository.resolvePlace('goong-place-id');
      final backend = RoomTestApi();
      addTearDown(backend.dispose);
      backend.responseData = roomJson;
      final posted = await backend.repository.postRoom(
        postRequest.name,
        postRequest.area,
        postRequest.waterFee,
        postRequest.serviceFee,
        postRequest.parkingFee,
        postRequest.rentalPrice,
        postRequest.electricityFee,
        postRequest.status,
        postRequest.roomType,
        selected,
        postRequest.interiors,
        postRequest.amenities,
        postRequest.images,
      );
      expect(posted, isA<DataSuccess>());
      backend.responseData = detailJson;
      final updated = await backend.repository.updateRoom(
        'room-id',
        location: selected,
      );
      expect(updated, isA<DataSuccess>());
      expect(backend.requests.map((request) => request.method), [
        'POST',
        'PATCH',
      ]);
      for (final request in backend.requests) {
        expect(request.data['location'], {
          'name': goongAddress,
          'latitude': 10.85,
          'longitude': 106.75,
        });
        expect(request.data.toString(), isNot(contains('api_key')));
        expect(request.data.toString(), isNot(contains('place_id')));
      }
    },
  );
}
