import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';

import 'package:roomio/features/room/domain/entities/room_request_entities.dart';
import 'package:roomio/features/room/domain/repository/room_repository.dart';

class UpdateStatusRoomUseCase
    extends UseCase<DataState<String>, UpdateRoomStatusRequestEntity> {
  final RoomRepository _roomRepository;

  UpdateStatusRoomUseCase(this._roomRepository);

  @override
  Future<DataState<String>> call(UpdateRoomStatusRequestEntity params) async {
    return await _roomRepository.updateStatusRoom(params.roomId, params.status);
  }
}
