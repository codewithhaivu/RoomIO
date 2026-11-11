import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/room/data/models/nearby_room_models.dart';
import 'package:roomio/features/saved_room/domain/entities/save_room.dart';
import 'package:roomio/features/saved_room/presentation/cubit/saved_rooms_cubit.dart';
import 'package:roomio/features/saved_room/presentation/cubit/saved_rooms_state.dart';
import 'saved_room_test_support.dart';

void main() {
  late FakeSaveRoomRepository repository;
  late SavedRoomsCubit cubit;
  setUp(() {
    repository = FakeSaveRoomRepository();
    cubit = repository.cubit();
  });
  tearDown(() => cubit.close());

  test(
    'saving updates both the heart flag and list before API completes, then rolls back on error',
    () async {
      final pending = Completer<DataState<String>>();
      repository.onSave = (_) => pending.future;
      final operation = cubit.toggle(room, isSaved: false);
      expect(cubit.state.isSaved(room.id), isTrue);
      expect(cubit.state.rooms, [room]);
      expect(cubit.state.pendingIds, {room.id});
      pending.complete(DataError(failure()));
      await operation;
      expect(cubit.state.isSaved(room.id), isFalse);
      expect(cubit.state.rooms, isEmpty);
      expect(cubit.state.pendingIds, isEmpty);
      expect(cubit.state.failureSequence, 1);
    },
  );

  test(
    'unsave removes immediately, failure restores the room at its old position',
    () async {
      repository.rooms = [otherRoom, room];
      await cubit.refresh();
      final pending = Completer<DataState<String>>();
      repository.onUnsave = (_) => pending.future;
      final operation = cubit.toggle(room, isSaved: true);
      expect(cubit.state.rooms, [otherRoom]);
      expect(cubit.state.isSaved(room.id), isFalse);
      pending.complete(DataError(failure()));
      await operation;
      expect(cubit.state.rooms, [otherRoom, room]);
      expect(cubit.state.isSaved(room.id), isTrue);
    },
  );

  test(
    'failed save does not roll back a successful save for another room',
    () async {
      final pending = Completer<DataState<String>>();
      repository.onSave = (id) => id == room.id
          ? pending.future
          : Future.value(const DataSuccess('Saved'));
      final first = cubit.toggle(room, isSaved: false);
      await cubit.toggle(otherRoom, isSaved: false);
      pending.complete(DataError(failure()));
      await first;
      expect(cubit.state.rooms, [otherRoom]);
      expect(cubit.state.isSaved(otherRoom.id), isTrue);
      expect(cubit.state.isSaved(room.id), isFalse);
    },
  );

  test(
    'rapid taps for one room are ignored while other rooms remain interactive',
    () async {
      final pending = Completer<DataState<String>>();
      repository.onSave = (_) => pending.future;
      final operation = cubit.toggle(room, isSaved: false);
      await cubit.toggle(room, isSaved: true);
      expect(repository.saves, [room.id]);
      expect(repository.unsaves, isEmpty);
      pending.complete(const DataSuccess('Saved'));
      await operation;
      expect(cubit.state.pendingIds, isEmpty);
    },
  );

  test(
    'GET started before a successful save cannot overwrite the newer write',
    () async {
      final response = Completer<DataState<ListSavedRoomResponse>>();
      repository.onGet = () => response.future;
      final refresh = cubit.refresh();
      await cubit.toggle(room, isSaved: false);
      response.complete(const DataSuccess(ListSavedRoomResponse(rooms: [])));
      await refresh;
      expect(cubit.state.rooms, [room]);
      expect(cubit.state.isSaved(room.id), isTrue);
    },
  );

  test(
    'GET started during unsave cannot re-add the room after that unsave succeeds',
    () async {
      repository.rooms = [room, otherRoom];
      await cubit.refresh();
      final pending = Completer<DataState<String>>();
      repository.onUnsave = (_) => pending.future;
      final mutation = cubit.toggle(room, isSaved: true);
      final response = Completer<DataState<ListSavedRoomResponse>>();
      repository.onGet = () => response.future;
      final refresh = cubit.refresh();
      pending.complete(const DataSuccess('Removed'));
      await mutation;
      response.complete(
        const DataSuccess(ListSavedRoomResponse(rooms: [room, otherRoom])),
      );
      await refresh;
      expect(cubit.state.rooms, [otherRoom]);
      expect(cubit.state.isSaved(room.id), isFalse);
    },
  );

  test(
    'GET during pending save keeps the optimistic item, then error removes it',
    () async {
      final pending = Completer<DataState<String>>();
      repository.onSave = (_) => pending.future;
      final operation = cubit.toggle(room, isSaved: false);
      await cubit.refresh();
      expect(cubit.state.rooms, [room]);
      pending.complete(DataError(failure()));
      await operation;
      expect(cubit.state.rooms, isEmpty);
    },
  );

  test(
    'latest refresh wins and authoritative refresh synchronizes known search flags',
    () async {
      cubit.observeRooms([
        NearbyRoomModel.fromJson({
          ...roomJson(),
          'distance': 1,
          'isSaved': true,
        }),
      ]);
      final first = Completer<DataState<ListSavedRoomResponse>>();
      final second = Completer<DataState<ListSavedRoomResponse>>();
      var calls = 0;
      repository.onGet = () => calls++ == 0 ? first.future : second.future;
      final a = cubit.refresh();
      final b = cubit.refresh();
      second.complete(const DataSuccess(ListSavedRoomResponse(rooms: [])));
      await b;
      first.complete(const DataSuccess(ListSavedRoomResponse(rooms: [room])));
      await a;
      expect(cubit.state.rooms, isEmpty);
      expect(cubit.state.isSaved(room.id, fallback: true), isFalse);
    },
  );

  test('stale search results never reset a local unsave', () async {
    repository.rooms = [room];
    await cubit.refresh();
    await cubit.toggle(room, isSaved: true);
    cubit.observeRooms([
      NearbyRoomModel.fromJson({
        ...roomJson(),
        'distance': 1,
        'is_saved': true,
      }),
    ]);
    expect(cubit.state.rooms, isEmpty);
    expect(cubit.state.isSaved(room.id, fallback: true), isFalse);
  });

  test(
    'refresh failures preserve cached rooms and successful optimistic changes',
    () async {
      await cubit.toggle(room, isSaved: false);
      repository.onGet = () async => DataError(failure(status: 500));
      await cubit.refresh();
      expect(cubit.state.status, SavedRoomsStatus.failure);
      expect(cubit.state.rooms, [room]);
      expect(cubit.state.isSaved(room.id), isTrue);
    },
  );

  test(
    'session reset clears all state and ignores previous account GET and write results',
    () async {
      final pending = Completer<DataState<String>>();
      repository.onSave = (_) => pending.future;
      final operation = cubit.toggle(room, isSaved: false);
      final response = Completer<DataState<ListSavedRoomResponse>>();
      repository.onGet = () => response.future;
      final refresh = cubit.refresh();
      cubit.reset();
      pending.complete(DataError(failure()));
      response.complete(
        const DataSuccess(ListSavedRoomResponse(rooms: [room])),
      );
      await Future.wait([operation, refresh]);
      expect(cubit.state, const SavedRoomsState());
    },
  );
}
