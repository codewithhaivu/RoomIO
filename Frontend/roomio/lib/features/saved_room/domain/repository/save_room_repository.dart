import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/saved_room/domain/entities/save_room.dart';

abstract class SaveRoomRepository {
  Future<DataState<String>> saveRoom(String roomId);
  Future<DataState<String>> unsaveRoom(String roomId);
  Future<DataState<ListSavedRoomResponse>> getSavedRooms();
}
