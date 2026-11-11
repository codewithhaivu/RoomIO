import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/room/data/data_sources/remote/room_catalog_api_service.dart';
import 'package:roomio/features/room/data/repository/room_catalog_repository_impl.dart';
import 'room_test_support.dart';

void main() {
  late RoomTestApi api;
  late RoomCatalogRepositoryImpl repository;
  setUp(() {
    api = RoomTestApi();
    repository = RoomCatalogRepositoryImpl(RoomCatalogApiService(api.dio));
  });
  tearDown(() => api.dispose());

  test(
    'catalog resolves actual backend endpoints and maps names and IDs',
    () async {
      api.responseFor = (request) => {
        'data': [
          {
            'id': request.uri.path == '/interior'
                ? 'interior-id'
                : 'amenity-id',
            'name': request.uri.path == '/interior' ? 'Bed' : 'Wifi',
          },
        ],
      };
      final result = await repository.getCatalog();
      expect(result, isA<DataSuccess>());
      expect(result.data!.interiors.single.id, 'interior-id');
      expect(result.data!.interiors.single.name, 'Bed');
      expect(result.data!.amenities.single.id, 'amenity-id');
      expect(result.data!.amenities.single.name, 'Wifi');
      expect(api.requests.map((request) => request.uri.path), [
        '/interior',
        '/amenitie',
      ]);
    },
  );

  test('catalog accepts empty lists', () async {
    api.responseData = {'data': []};
    final result = await repository.getCatalog();
    expect(result.data!.interiors, isEmpty);
    expect(result.data!.amenities, isEmpty);
  });

  test('catalog propagates a network failure', () async {
    final error = DioException(
      requestOptions: RequestOptions(path: '/interior'),
    );
    api.error = error;
    final result = await repository.getCatalog();
    expect(result, isA<DataError>());
    expect(result.error, same(error));
  });

  test('catalog preserves a non-success response', () async {
    api.responseData = {'data': []};
    api.statusCode = 500;
    final result = await repository.getCatalog();
    expect(result, isA<DataError>());
    expect(result.error!.response!.statusCode, 500);
    expect(result.error!.type, DioExceptionType.badResponse);
  });
}
