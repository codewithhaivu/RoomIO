import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/room/domain/entities/room_sub_entities.dart';
import 'package:roomio/features/room/domain/repository/room_places_repository.dart';

class ResolveRoomPlaceParams {
  final String placeId;
  const ResolveRoomPlaceParams(this.placeId);
}

class ResolveRoomPlaceUseCase
    extends UseCase<LocationEntity, ResolveRoomPlaceParams> {
  final RoomPlacesRepository _repository;
  ResolveRoomPlaceUseCase(this._repository);
  @override
  Future<LocationEntity> call(ResolveRoomPlaceParams params) =>
      _repository.resolvePlace(params.placeId);
}
