import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/room/domain/entities/room_sub_entities.dart';
import 'package:roomio/features/room/domain/repository/room_location_repository.dart';

class SearchRoomLocationsUseCase extends UseCase<List<LocationEntity>, String> {
  final RoomLocationRepository _repository;
  SearchRoomLocationsUseCase(this._repository);

  @override
  Future<List<LocationEntity>> call(String params) =>
      _repository.searchLocations(params);
}
