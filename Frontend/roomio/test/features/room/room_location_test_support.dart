import 'package:roomio/features/room/domain/entities/room_location_error.dart';
import 'package:roomio/features/room/domain/entities/room_sub_entities.dart';
import 'package:roomio/features/room/domain/repository/room_location_repository.dart';

class FakeRoomLocationRepository implements RoomLocationRepository {
  static const location = LocationEntity(
    name: 'Thủ Đức',
    latitude: 10.8,
    longitude: 106.7,
  );
  Future<LocationEntity> Function()? current;
  Future<List<LocationEntity>> Function(String)? search;
  Future<LocationEntity> Function(LocationEntity)? reverse;
  RoomLocationIssue? failure;
  int gpsCalls = 0;
  final queries = <String>[];
  final settingsOpened = <RoomLocationSettings>[];

  @override
  Future<LocationEntity> getCurrentLocation() async {
    gpsCalls++;
    if (failure != null) throw RoomLocationException(failure!);
    return current == null ? location : await current!();
  }

  @override
  Future<List<LocationEntity>> searchLocations(String address) async {
    queries.add(address);
    if (failure != null) throw RoomLocationException(failure!);
    return search == null ? [location] : await search!(address);
  }

  @override
  Future<bool> openSettings(RoomLocationSettings settings) async {
    settingsOpened.add(settings);
    return true;
  }

  @override
  Future<LocationEntity> reverseGeocode(LocationEntity coordinates) async {
    if (failure != null) throw RoomLocationException(failure!);
    return reverse == null
        ? LocationEntity(
            name: '12 Đường Võ Văn Ngân, Thủ Đức',
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
          )
        : await reverse!(coordinates);
  }
}
