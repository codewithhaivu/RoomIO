import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/room/data/models/nearby_room_models.dart';
import 'package:roomio/features/saved_room/data/models/save_room.dart';
import 'package:roomio/features/saved_room/domain/entities/save_room.dart';
import 'saved_room_test_support.dart';

void main() {
  late SavedRoomTestApi api;
  setUp(() => api = SavedRoomTestApi());
  tearDown(() => api.dio.close(force: true));

  test(
    'GET maps integer numbers, null image and models into immutable entities',
    () async {
      api.data = {
        'rooms': [roomJson()],
      };
      final result = await api.repository.getSavedRooms();
      expect(result, isA<DataSuccess<ListSavedRoomResponse>>());
      expect(result.data!.rooms.single, room);
      expect(result.data!.rooms.single, isNot(isA<RoomResponseModel>()));
      expect(() => result.data!.rooms.clear(), throwsUnsupportedError);
      expect(api.requests.single.method, 'GET');
      expect(api.requests.single.uri.path, '/saved-rooms/');
    },
  );

  test('nullable or empty saved-room lists represent an empty state', () async {
    for (final rooms in [null, []]) {
      api.data = {'rooms': rooms};
      final result = await api.repository.getSavedRooms();
      expect(result.data!.rooms, isEmpty);
    }
  });

  test(
    'POST uses room ID with no body and accepts 201; DELETE returns message',
    () async {
      api.status = 201;
      api.data = {'message': 'Successful'};
      expect((await api.repository.saveRoom(room.id)).data, 'Successful');
      expect(api.requests.single.method, 'POST');
      expect(api.requests.single.uri.path, '/saved-rooms/room-id');
      expect(api.requests.single.data, isNull);
      api.status = 200;
      expect((await api.repository.unsaveRoom(room.id)).data, 'Successful');
      expect(api.requests.last.method, 'DELETE');
      expect(api.requests.last.uri.path, '/saved-rooms/room-id');
    },
  );

  test(
    'all APIs preserve authorization, network and server errors for rollback',
    () async {
      for (final status in [401, 403, 404, 500]) {
        api.error = failure(status: status);
        final results = await Future.wait([
          api.repository.getSavedRooms(),
          api.repository.saveRoom(room.id),
          api.repository.unsaveRoom(room.id),
        ]);
        for (final result in results) {
          expect(result.error, same(api.error));
          expect(result.error!.response!.statusCode, status);
        }
      }
      api.error = DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.connectionError,
      );
      expect((await api.repository.saveRoom(room.id)).error, same(api.error));
    },
  );

  test(
    'malformed saved response and missing DELETE message are DataError',
    () async {
      api.data = {
        'rooms': [
          {'id': 'broken'},
        ],
      };
      expect(
        await api.repository.getSavedRooms(),
        isA<DataError<ListSavedRoomResponse>>(),
      );
      api.data = null;
      expect(
        await api.repository.unsaveRoom(room.id),
        isA<DataError<String>>(),
      );
    },
  );

  test(
    'search DTO supports isSaved and is_saved without coercing invalid types',
    () {
      final json = {...roomJson(), 'distance': 1.2};
      expect(
        NearbyRoomModel.fromJson({...json, 'isSaved': true}).isSaved,
        isTrue,
      );
      expect(
        NearbyRoomModel.fromJson({...json, 'is_saved': true}).isSaved,
        isTrue,
      );
      expect(NearbyRoomModel.fromJson(json).isSaved, isFalse);
      expect(
        () => NearbyRoomModel.fromJson({...json, 'isSaved': 'true'}),
        throwsA(isA<TypeError>()),
      );
    },
  );
}
