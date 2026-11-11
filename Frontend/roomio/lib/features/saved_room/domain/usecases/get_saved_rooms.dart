import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/saved_room/domain/entities/save_room.dart';
import 'package:roomio/features/saved_room/domain/repository/save_room_repository.dart';

class GetSavedRoomsUseCase
    extends UseCase<DataState<ListSavedRoomResponse>, void> {
  final SaveRoomRepository _repository;
  GetSavedRoomsUseCase(this._repository);

  @override
  Future<DataState<ListSavedRoomResponse>> call(void params) =>
      _repository.getSavedRooms();
}
