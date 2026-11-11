import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/room/domain/entities/room_detail_entities.dart';
import 'package:roomio/features/room/domain/entities/room_request_entities.dart';
import 'package:roomio/features/room/domain/repository/room_repository.dart';

class UpdateRoomUseCase
    extends UseCase<DataState<RoomDetailEntity>, UpdateRoomRequestEntity> {
  final RoomRepository _roomRepository;

  UpdateRoomUseCase(this._roomRepository);

  @override
  Future<DataState<RoomDetailEntity>> call(
    UpdateRoomRequestEntity params,
  ) async {
    return await _roomRepository.updateRoom(
      params.roomId,
      name: params.name,
      area: params.area,
      waterFee: params.waterFee,
      serviceFee: params.serviceFee,
      parkingFee: params.parkingFee,
      rentalPrice: params.rentalPrice,
      electricityFee: params.electricityFee,
      status: params.status,
      roomType: params.roomType,
      location: params.location,
      interiors: params.interiors,
      amenities: params.amenities,
      images: params.images,
    );
  }
}
