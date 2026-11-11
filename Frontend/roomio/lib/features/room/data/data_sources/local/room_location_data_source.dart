import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:roomio/features/room/domain/entities/room_location_error.dart';
import 'package:roomio/features/room/domain/entities/room_sub_entities.dart';

class RoomLocationDataSource {
  final GeolocatorPlatform _geolocator;
  final geo.Geocoding Function() _geocoderFactory;

  RoomLocationDataSource({
    GeolocatorPlatform? geolocator,
    geo.Geocoding Function()? geocoderFactory,
  }) : _geolocator = geolocator ?? GeolocatorPlatform.instance,
       _geocoderFactory = geocoderFactory ?? geo.Geocoding.new;

  Future<LocationEntity> getCurrentLocation() async {
    if (!await _geolocator.isLocationServiceEnabled()) {
      throw const RoomLocationException(RoomLocationIssue.serviceDisabled);
    }
    var permission = await _geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const RoomLocationException(
        RoomLocationIssue.permissionDeniedForever,
      );
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      throw const RoomLocationException(RoomLocationIssue.permissionDenied);
    }
    final position = await _geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return LocationEntity(
      name: 'Vị trí của bạn',
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  Future<List<LocationEntity>> searchLocations(String address) async {
    if (kIsWeb ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        ].contains(defaultTargetPlatform)) {
      throw const RoomLocationException(RoomLocationIssue.unsupported);
    }
    final query = address.trim();
    if (query.isEmpty) {
      throw const RoomLocationException(RoomLocationIssue.addressNotFound);
    }
    final geocoder = _geocoderFactory();
    final locations = await geocoder
        .locationFromAddress(query, locale: const Locale('vi', 'VN'))
        .timeout(const Duration(seconds: 12));
    final unique = <String>{};
    final candidates = locations
        .where(
          (location) =>
              location.latitude.isFinite &&
              location.longitude.isFinite &&
              location.latitude.abs() <= 90 &&
              location.longitude.abs() <= 180 &&
              unique.add('${location.latitude},${location.longitude}'),
        )
        .take(3)
        .toList();
    if (candidates.isEmpty) {
      throw const RoomLocationException(RoomLocationIssue.addressNotFound);
    }
    return Future.wait(
      candidates.asMap().entries.map((entry) async {
        final location = entry.value;
        var name = candidates.length == 1
            ? query
            : '$query · Kết quả ${entry.key + 1}';
        if (candidates.length > 1) {
          // Phân biệt các địa điểm trùng tên; lỗi reverse geocoding không làm mất tọa độ.
          try {
            final marks = await geocoder
                .placemarkFromCoordinates(
                  location.latitude,
                  location.longitude,
                  locale: const Locale('vi', 'VN'),
                )
                .timeout(const Duration(seconds: 3));
            if (marks.isNotEmpty) {
              final mark = marks.first;
              final parts =
                  [
                        mark.name,
                        mark.street,
                        mark.subAdministrativeArea,
                        mark.administrativeArea,
                        mark.country,
                      ]
                      .whereType<String>()
                      .where((part) => part.trim().isNotEmpty)
                      .toSet();
              if (parts.isNotEmpty) name = parts.join(', ');
            }
          } on Exception catch (_) {
            // Giữ tên truy vấn để người dùng có thể chọn hoặc nhập địa chỉ cụ thể hơn.
          }
        }
        return LocationEntity(
          name: name,
          latitude: location.latitude,
          longitude: location.longitude,
        );
      }),
    );
  }

  Future<LocationEntity> reverseGeocode(LocationEntity location) async {
    if (kIsWeb ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        ].contains(defaultTargetPlatform)) {
      throw const RoomLocationException(RoomLocationIssue.unsupported);
    }
    final marks = await _geocoderFactory()
        .placemarkFromCoordinates(
          location.latitude,
          location.longitude,
          locale: const Locale('vi', 'VN'),
        )
        .timeout(const Duration(seconds: 12));
    if (marks.isEmpty) {
      throw const RoomLocationException(RoomLocationIssue.addressNotFound);
    }
    final mark = marks.first;
    final street = mark.street?.trim();
    final parts =
        [
              street != null && street.isNotEmpty ? street : mark.name,
              mark.subLocality,
              mark.subAdministrativeArea,
              mark.locality,
              mark.administrativeArea,
              mark.country,
            ]
            .whereType<String>()
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toSet();
    if (parts.isEmpty) {
      throw const RoomLocationException(RoomLocationIssue.addressNotFound);
    }
    return LocationEntity(
      name: parts.join(', '),
      latitude: location.latitude,
      longitude: location.longitude,
    );
  }

  Future<bool> openSettings(RoomLocationSettings settings) =>
      settings == RoomLocationSettings.app
      ? _geolocator.openAppSettings()
      : _geolocator.openLocationSettings();
}
