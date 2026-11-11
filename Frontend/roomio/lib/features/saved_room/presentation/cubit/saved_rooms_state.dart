import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:roomio/features/saved_room/domain/entities/save_room.dart';

enum SavedRoomsStatus { initial, loading, success, failure }

class SavedRoomsState extends Equatable {
  final SavedRoomsStatus status;
  final List<RoomResponse> rooms;
  final Map<String, bool> savedById;
  final Set<String> pendingIds;
  final DioException? loadError;
  final DioException? mutationError;
  final String? failedRoomId;
  final int failureSequence;

  const SavedRoomsState({
    this.status = SavedRoomsStatus.initial,
    this.rooms = const [],
    this.savedById = const {},
    this.pendingIds = const {},
    this.loadError,
    this.mutationError,
    this.failedRoomId,
    this.failureSequence = 0,
  });

  bool get isLoading => status == SavedRoomsStatus.loading;
  bool isSaved(String roomId, {bool fallback = false}) =>
      savedById[roomId] ?? fallback;

  SavedRoomsState copyWith({
    SavedRoomsStatus? status,
    List<RoomResponse>? rooms,
    Map<String, bool>? savedById,
    Set<String>? pendingIds,
    DioException? loadError,
    bool clearLoadError = false,
    DioException? mutationError,
    String? failedRoomId,
    int? failureSequence,
  }) => SavedRoomsState(
    status: status ?? this.status,
    rooms: rooms == null ? this.rooms : List.unmodifiable(rooms),
    savedById: savedById == null ? this.savedById : Map.unmodifiable(savedById),
    pendingIds: pendingIds == null
        ? this.pendingIds
        : Set.unmodifiable(pendingIds),
    loadError: clearLoadError ? null : loadError ?? this.loadError,
    mutationError: mutationError ?? this.mutationError,
    failedRoomId: failedRoomId ?? this.failedRoomId,
    failureSequence: failureSequence ?? this.failureSequence,
  );

  @override
  List<Object?> get props => [
    status,
    rooms,
    savedById,
    pendingIds,
    loadError,
    mutationError,
    failedRoomId,
    failureSequence,
  ];
}
