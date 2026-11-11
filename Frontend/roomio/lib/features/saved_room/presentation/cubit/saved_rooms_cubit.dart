import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/room/domain/entities/nearby_room_entities.dart';
import 'package:roomio/features/saved_room/domain/entities/save_room.dart';
import 'package:roomio/features/saved_room/domain/usecases/get_saved_rooms.dart';
import 'package:roomio/features/saved_room/domain/usecases/save_room.dart';
import 'package:roomio/features/saved_room/domain/usecases/unsave_room.dart';
import 'saved_rooms_state.dart';

/// Shared by search and saved-room routes for the current signed-in session.
class SavedRoomsCubit extends Cubit<SavedRoomsState> {
  final GetSavedRoomsUseCase _getRooms;
  final SaveRoomUseCase _saveRoom;
  final UnsaveRoomUseCase _unsaveRoom;
  final Map<String, int> _versions = {};
  int _session = 0;
  int _loadId = 0;

  SavedRoomsCubit(this._getRooms, this._saveRoom, this._unsaveRoom)
    : super(const SavedRoomsState());

  /// Seed new search results without replacing local writes with stale DTOs.
  void observeRooms(List<NearbyRoomEntity> rooms) {
    if (isClosed) return;
    final flags = {...state.savedById};
    final saved = {for (final room in state.rooms) room.id: room};
    for (final room in rooms) {
      if (flags.containsKey(room.id)) continue;
      flags[room.id] = room.isSaved;
      if (room.isSaved) saved[room.id] = RoomResponse.fromNearbyRoom(room);
    }
    emit(state.copyWith(rooms: saved.values.toList(), savedById: flags));
  }

  Future<void> refresh() async {
    if (isClosed) return;
    final session = _session;
    final request = ++_loadId;
    final versions = {..._versions};
    final pendingAtStart = {...state.pendingIds};
    emit(
      state.copyWith(status: SavedRoomsStatus.loading, clearLoadError: true),
    );
    final result = await _getRooms(null);
    if (isClosed || session != _session || request != _loadId) return;
    if (result is! DataSuccess<ListSavedRoomResponse>) {
      emit(
        state.copyWith(
          status: SavedRoomsStatus.failure,
          loadError: result.error,
        ),
      );
      return;
    }
    final remote = {for (final room in result.data!.rooms) room.id: room};
    final current = {for (final room in state.rooms) room.id: room};
    final flags = <String, bool>{};
    final ids = {...state.savedById.keys, ...remote.keys, ..._versions.keys};
    for (final id in ids) {
      // A GET started before/during a mutation must not reverse that mutation.
      final protected =
          state.pendingIds.contains(id) ||
          pendingAtStart.contains(id) ||
          _versions[id] != versions[id];
      final saved = protected ? state.isSaved(id) : remote.containsKey(id);
      flags[id] = saved;
      if (!saved) {
        remote.remove(id);
      } else if (protected && current[id] != null) {
        remote[id] = current[id]!;
      }
    }
    emit(
      state.copyWith(
        status: SavedRoomsStatus.success,
        rooms: remote.values.toList(),
        savedById: flags,
        clearLoadError: true,
      ),
    );
  }

  Future<void> toggle(RoomResponse room, {required bool isSaved}) async {
    if (isClosed || state.pendingIds.contains(room.id)) return;
    final session = _session;
    final previous = state.isSaved(room.id, fallback: isSaved);
    final target = !previous;
    final oldIndex = state.rooms.indexWhere((item) => item.id == room.id);
    final oldRoom = oldIndex < 0 ? room : state.rooms[oldIndex];
    _versions[room.id] = (_versions[room.id] ?? 0) + 1;
    final updated = state.rooms.where((item) => item.id != room.id).toList();
    if (target) updated.insert(0, room);
    emit(
      state.copyWith(
        rooms: updated,
        savedById: {...state.savedById, room.id: target},
        pendingIds: {...state.pendingIds, room.id},
      ),
    );
    final result = target
        ? await _saveRoom(room.id)
        : await _unsaveRoom(room.id);
    if (isClosed || session != _session) return;
    _versions[room.id] = (_versions[room.id] ?? 0) + 1;
    final pending = {...state.pendingIds}..remove(room.id);
    if (result is DataSuccess<String>) {
      emit(state.copyWith(pendingIds: pending));
      return;
    }
    // Roll back this room only, preserving successful writes for other rooms.
    final restored = state.rooms.where((item) => item.id != room.id).toList();
    if (previous) {
      restored.insert(
        oldIndex < 0 ? 0 : oldIndex.clamp(0, restored.length),
        oldRoom,
      );
    }
    emit(
      state.copyWith(
        rooms: restored,
        savedById: {...state.savedById, room.id: previous},
        pendingIds: pending,
        mutationError: result.error,
        failedRoomId: room.id,
        failureSequence: state.failureSequence + 1,
      ),
    );
  }

  /// Invalidates in-flight responses as well as data from the previous account.
  void reset() {
    if (isClosed) return;
    _session++;
    _loadId++;
    _versions.clear();
    emit(const SavedRoomsState());
  }
}
