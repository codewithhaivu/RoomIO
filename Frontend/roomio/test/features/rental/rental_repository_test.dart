import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/rental/data/models/rental.dart';
import 'package:roomio/features/rental/domain/entities/rental.dart';
import 'rental_test_support.dart';

void main() {
  late RentalTestApi api;
  setUp(() => api = RentalTestApi());
  tearDown(() => api.dispose());

  test('QR creation uses the correct absolute path and accepts 201', () async {
    api.responseData = {'qr_token': '012345', 'expires_in_second': 60};
    api.statusCode = 201;
    final result = await api.repository.createQRCode('room-id');
    expect(result.data!.qrToken, '012345');
    expect(result.data!.expiresInSecond, 60);
    expect(api.requests.single.uri.path, '/rentals/room-id/qr-code');
    expect(api.requests.single.method, 'POST');
  });

  test(
    'verify uses POST, preserves leading zero and maps backend id_valid',
    () async {
      api.responseData = {'message': 'Confirmed', 'id_valid': true};
      final result = await api.repository.verifyQRCode(
        const RentalVerifyRequest(token: '012345'),
      );
      expect(result.data!.isValid, isTrue);
      expect(api.requests.single.uri.path, '/rentals/qr-code/verify');
      expect(api.requests.single.method, 'POST');
      expect(api.requests.single.data, {'token': '012345'});
    },
  );

  test('verification false is preserved and the legacy key is supported', () {
    expect(
      RentalModelVerifyResponse.fromJson({
        'message': 'Invalid',
        'id_valid': false,
        'is_valid': true,
      }).isValid,
      isFalse,
    );
    expect(
      RentalModelVerifyResponse.fromJson({
        'message': 'Valid',
        'is_valid': true,
      }).isValid,
      isTrue,
    );
  });

  test(
    'landlord list unwraps data and does not invent a missing rental relation id',
    () async {
      api.responseData = {
        'data': [tenantJson..remove('rental_id')],
      };
      final result = await api.repository.getMyTenants();
      expect(result.data!.single.tenantId, 'tenant-id');
      expect(result.data!.single.rentalId, isNull);
      expect(api.requests.single.uri.path, '/rentals/');
      expect(api.requests.single.queryParameters, isEmpty);
      api.responseData = {'data': []};
      expect((await api.repository.getMyTenants()).data, isEmpty);
    },
  );

  test(
    'tenant list unwraps data, date and integer price without needing an id parameter',
    () async {
      api.responseData = {
        'data': [rentedRoomJson],
      };
      final result = await api.repository.getCurrentRentRoom();
      expect(result.data!.single, rentedRoom);
      expect(result.data!.single.price, 3500000.0);
      expect(api.requests.single.uri.path, '/rentals/my-rooms');
      expect(api.requests.single.queryParameters, isEmpty);
    },
  );

  test(
    'destroy sends the relation id using DELETE and unwraps the message',
    () async {
      api.responseData = {'message': 'Ended'};
      expect((await api.repository.destroyRelation('rental-id')).data, 'Ended');
      expect(api.requests.single.method, 'DELETE');
      expect(api.requests.single.uri.path, '/rentals/rental-id');
    },
  );

  for (final operation in ['create', 'verify', 'tenants', 'rooms', 'destroy']) {
    Future<DataState<dynamic>> run() => switch (operation) {
      'create' => api.repository.createQRCode('room-id'),
      'verify' => api.repository.verifyQRCode(
        const RentalVerifyRequest(token: '012345'),
      ),
      'tenants' => api.repository.getMyTenants(),
      'rooms' => api.repository.getCurrentRentRoom(),
      _ => api.repository.destroyRelation('rental-id'),
    };
    test(
      '$operation keeps DioException and server detail for the UI',
      () async {
        final options = RequestOptions();
        api.error = DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: options,
            statusCode: 403,
            data: {'detail': 'Không có quyền'},
          ),
        );
        final result = await run();
        expect(result, isA<DataError>());
        expect(result.error, same(api.error));
      },
    );
    test('$operation rejects an unexpected HTTP status', () async {
      api.statusCode = 202;
      api.responseData = switch (operation) {
        'create' => {'qr_token': '012345', 'expires_in_second': 60},
        'verify' => {'message': 'Valid', 'id_valid': true},
        'tenants' => {
          'data': [tenantJson],
        },
        'rooms' => {
          'data': [rentedRoomJson],
        },
        _ => {'message': 'Ended'},
      };
      final result = await run();
      expect(result, isA<DataError>());
      expect(result.error!.response!.statusCode, 202);
    });
  }
}
