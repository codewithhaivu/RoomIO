import 'package:roomio/features/room/domain/entities/room_location_error.dart';
import 'package:roomio/features/room/domain/entities/room_sub_entities.dart';

abstract class RoomLocationRepository {
  Future<LocationEntity> getCurrentLocation();
  Future<LocationEntity> reverseGeocode(LocationEntity location);
  Future<List<LocationEntity>> searchLocations(String address);
  Future<bool> openSettings(RoomLocationSettings settings);
}
