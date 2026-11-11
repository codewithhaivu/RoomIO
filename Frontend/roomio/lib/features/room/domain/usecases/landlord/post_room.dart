import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/room/domain/entities/room_entities.dart';
import 'package:roomio/features/room/domain/entities/room_request_entities.dart';
import 'package:roomio/features/room/domain/repository/room_repository.dart';

class PostRoomUseCase
    extends UseCase<DataState<RoomEntity>, PostRoomRequestEntity> {
  final RoomRepository _roomRepository;

  PostRoomUseCase(this._roomRepository);

  @override
  Future<DataState<RoomEntity>> call(PostRoomRequestEntity params) async {
    return await _roomRepository.postRoom(
      params.name,
      params.area,
      params.waterFee,
      params.serviceFee,
      params.parkingFee,
      params.rentalPrice,
      params.electricityFee,
      params.status,
      params.roomType,
      params.location,
      params.interiors,
      params.amenities,
      params.images,
    );
  }
}
