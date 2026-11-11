import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/room/domain/entities/nearby_room_entities.dart';
import 'package:roomio/features/room/domain/entities/room_detail_entities.dart';
import 'package:roomio/features/room/domain/entities/room_entities.dart';
import 'package:roomio/features/room/domain/entities/room_place_suggestion.dart';
import 'package:roomio/features/room/domain/entities/room_sub_entities.dart';
import 'room_test_support.dart';

void main() {
  late RoomTestApi api;
  setUp(() => api = RoomTestApi());
  tearDown(() => api.dispose());

  test(
    'location suggestions unwrap data and preserve district identity',
    () async {
      api.responseData = {
        'data': [
          {'location_id': 'thu-duc-id', 'name_district': 'Thủ Đức'},
        ],
      };
      final result = await api.repository.getLocationSuggestion();
      expect(result, isA<DataSuccess<List<LocationSuggestion>>>());
      expect(result.data, hasLength(1));
      expect(result.data!.single.locationId, 'thu-duc-id');
      expect(result.data!.single.nameDistrict, 'Thủ Đức');
      expect(api.requests.single.method, 'GET');
      expect(api.requests.single.uri.path, endsWith('/rooms/locations'));
    },
  );

  test(
    'malformed location response returns DataError without fallback',
    () async {
      api.responseData = {'data': 'invalid'};
      final result = await api.repository.getLocationSuggestion();
      expect(result, isA<DataError>());
      expect(result.data, isNull);
      expect(result.error!.error, isA<TypeError>());
    },
  );

  final cases =
      <
        String,
        (Object Function(), Future<DataState<dynamic>> Function(RoomTestApi))
      >{
        'postRoom': (() => roomJson, (api) => api.postRoom()),
        'uploadImages': (
          () => {
            'response': [imageJson],
          },
          (api) => api.repository.uploadImages([api.imageFile], [true]),
        ),
        'getListRoom': (
          () => {
            'rooms': [roomJson],
          },
          (api) => api.repository.getListRoom(),
        ),
        'getDetailRoom': (
          () => detailJson,
          (api) => api.repository.getDetailRoom('room-id'),
        ),
        'updateRoom': (
          () => detailJson,
          (api) => api.repository.updateRoom('room-id', rentalPrice: 5000000),
        ),
        'updateStatusRoom': (
          () => {'Message': 'Updated'},
          (api) => api.repository.updateStatusRoom('room-id', 'RENTED'),
        ),
        'searchRoomByPosition': (
          () => {
            'rooms': [nearbyJson],
          },
          (api) => api.repository.searchRoomByPosition(10.8, 106.7, 5),
        ),
        'searchRoomsByArea': (
          () => {
            'rooms': [nearbyJson],
          },
          (api) => api.repository.searchRoomsByArea('location-id', 'Thu Duc'),
        ),
        'getLocationSuggestion': (
          () => {
            'data': [
              {'location_id': 'location-id', 'name_district': 'Thủ Đức'},
            ],
          },
          (api) => api.repository.getLocationSuggestion(),
        ),
      };

  for (final entry in cases.entries) {
    group(entry.key, () {
      test('returns DataSuccess for HTTP 200', () async {
        api.responseData = entry.value.$1();
        final result = await entry.value.$2(api);
        expect(result, isA<DataSuccess>());
        expect(result.data, isNotNull);
      });

      test(
        'returns DataError and preserves unexpected HTTP response',
        () async {
          api.responseData = entry.value.$1();
          api.statusCode = HttpStatus.badRequest;
          final result = await entry.value.$2(api);
          expect(result, isA<DataError>());
          expect(result.error!.type, DioExceptionType.badResponse);
          expect(result.error!.response!.statusCode, HttpStatus.badRequest);
          expect(result.error!.requestOptions, same(api.requests.single));
        },
      );

      test('returns DataError with the original DioException', () async {
        final error = DioException(
          requestOptions: RequestOptions(path: '/rooms'),
          type: DioExceptionType.connectionTimeout,
        );
        api.error = error;
        final result = await entry.value.$2(api);
        expect(result, isA<DataError>());
        expect(result.error, same(error));
      });
    });
  }

  test(
    'postRoom converts domain entities and preserves every request field',
    () async {
      api.responseData = roomJson;
      api.statusCode = HttpStatus.created;
      final result = await api.postRoom();
      expect(result, isA<DataSuccess<RoomEntity>>());
      expect(api.requests.single.data, {
        'name': postRequest.name,
        'area': postRequest.area,
        'water_fee': postRequest.waterFee,
        'service_fee': postRequest.serviceFee,
        'parking_fee': postRequest.parkingFee,
        'rental_price': postRequest.rentalPrice,
        'electricity_fee': postRequest.electricityFee,
        'status': postRequest.status,
        'room_type': postRequest.roomType,
        'location': {
          'name': location.name,
          'longitude': location.longitude,
          'latitude': location.latitude,
        },
        'interiors': postRequest.interiors,
        'amenities': postRequest.amenities,
        'images': [imageJson],
      });
    },
  );

  test(
    'uploadImages unwraps images and sends thumbnail multipart fields',
    () async {
      api.responseData = {
        'response': [imageJson],
      };
      api.statusCode = HttpStatus.created;
      final result = await api.repository.uploadImages([api.imageFile], [true]);
      expect(result, isA<DataSuccess<List<RoomImageEntity>>>());
      expect(result.data!.single.props, image.props);
      final data = api.requests.single.data as FormData;
      expect(data.files.single.key, 'images');
      expect(data.fields.single.key, 'is_thumbnails');
      expect(data.fields.single.value, 'true');
    },
  );

  test(
    'updateRoom omits null fields and preserves explicit empty lists and zero',
    () async {
      api.responseData = detailJson;
      final result = await api.repository.updateRoom(
        'room-id',
        parkingFee: 0,
        interiors: [],
        images: [],
      );
      expect(result, isA<DataSuccess<RoomDetailEntity>>());
      expect(api.requests.single.path, '/room-id');
      expect(api.requests.single.data, {
        'parking_fee': 0.0,
        'interiors': [],
        'images': [],
      });
    },
  );

  test('updateRoom converts optional location and images', () async {
    api.responseData = detailJson;
    await api.repository.updateRoom(
      'room-id',
      location: location,
      images: [image],
    );
    expect(api.requests.single.data, {
      'location': {
        'name': location.name,
        'longitude': location.longitude,
        'latitude': location.latitude,
      },
      'images': [imageJson],
    });
  });

  test(
    'status response reads Message and rejects malformed success payloads',
    () async {
      api.responseData = {'Message': 'Room updated'};
      expect(
        (await api.repository.updateStatusRoom('room-id', 'RENTED')).data,
        'Room updated',
      );
      for (final payload in [
        null,
        'Updated',
        {'Message': 1},
        {'message': 'wrong key'},
      ]) {
        api.responseData = payload;
        expect(
          await api.repository.updateStatusRoom('room-id', 'RENTED'),
          isA<DataError<String>>(),
        );
      }
    },
  );

  test(
    'search methods unwrap results and forward query parameters and default radius',
    () async {
      api.responseData = {
        'rooms': [nearbyJson],
      };
      final result = await api.repository.searchRoomByPosition(10.8, 106.7, 5);
      expect(result, isA<DataSuccess<List<NearbyRoomEntity>>>());
      expect(result.data!.single.distance, 1.5);
      expect(api.requests.last.queryParameters, {
        'latitude': 10.8,
        'longitude': 106.7,
        'radius': 5.0,
      });
      await api.repository.searchRoomsByArea('location-id', 'Thu Duc');
      expect(api.requests.last.queryParameters, {
        'location_id': 'location-id',
        'district': 'Thu Duc',
        'radius': 10.0,
      });
      await api.repository.searchRoomsByArea(
        'location-id',
        'Thu Duc',
        radius: 3,
      );
      expect(api.requests.last.queryParameters['radius'], 3);
    },
  );

  test('empty wrappers produce successful empty lists', () async {
    api.responseData = {'rooms': []};
    expect((await api.repository.getListRoom()).data, isEmpty);
    expect(
      (await api.repository.searchRoomByPosition(10.8, 106.7, 5)).data,
      isEmpty,
    );
    api.responseData = {'response': []};
    expect(
      (await api.repository.uploadImages([api.imageFile], [true])).data,
      isEmpty,
    );
  });
}
