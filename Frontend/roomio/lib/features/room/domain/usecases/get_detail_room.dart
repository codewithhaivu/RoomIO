import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/room/domain/entities/room_detail_entities.dart';

import 'package:roomio/features/room/domain/repository/room_repository.dart';

class GetDetailRoomUseCase
    extends UseCase<DataState<RoomDetailEntity>, String> {
  final RoomRepository _roomRepository;

  GetDetailRoomUseCase(this._roomRepository);

  @override
  Future<DataState<RoomDetailEntity>> call(String params) async {
    return await _roomRepository.getDetailRoom(params);
  }
}
