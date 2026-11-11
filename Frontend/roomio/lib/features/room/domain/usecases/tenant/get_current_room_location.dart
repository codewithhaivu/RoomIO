import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/room/domain/entities/room_sub_entities.dart';
import 'package:roomio/features/room/domain/repository/room_location_repository.dart';

class GetCurrentRoomLocationUseCase extends UseCase<LocationEntity, void> {
  final RoomLocationRepository _repository;
  GetCurrentRoomLocationUseCase(this._repository);

  @override
  Future<LocationEntity> call(void params) => _repository.getCurrentLocation();
}
