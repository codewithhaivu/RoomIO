import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/room/domain/entities/room_entities.dart';

import 'package:roomio/features/room/domain/repository/room_repository.dart';

class GetListRoomUseCase extends UseCase<DataState<List<RoomEntity>>, void> {
  final RoomRepository _roomRepository;

  GetListRoomUseCase(this._roomRepository);

  @override
  Future<DataState<List<RoomEntity>>> call(void params) async {
    return await _roomRepository.getListRoom();
  }
}
