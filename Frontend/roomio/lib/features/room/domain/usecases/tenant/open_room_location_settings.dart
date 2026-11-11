import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/room/domain/entities/room_location_error.dart';
import 'package:roomio/features/room/domain/repository/room_location_repository.dart';

class OpenRoomLocationSettingsUseCase
    extends UseCase<bool, RoomLocationSettings> {
  final RoomLocationRepository _repository;
  OpenRoomLocationSettingsUseCase(this._repository);

  @override
  Future<bool> call(RoomLocationSettings params) =>
      _repository.openSettings(params);
}
