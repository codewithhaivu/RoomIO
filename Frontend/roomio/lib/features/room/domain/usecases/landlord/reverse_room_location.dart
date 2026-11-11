import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/room/domain/entities/room_sub_entities.dart';
import 'package:roomio/features/room/domain/repository/room_location_repository.dart';

class ReverseRoomLocationUseCase
    extends UseCase<LocationEntity, LocationEntity> {
  final RoomLocationRepository _repository;
  ReverseRoomLocationUseCase(this._repository);
  @override
  Future<LocationEntity> call(LocationEntity params) =>
      _repository.reverseGeocode(params);
}
