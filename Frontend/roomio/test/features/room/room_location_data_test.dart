import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:roomio/features/room/data/data_sources/local/room_location_data_source.dart';
import 'package:roomio/features/room/data/repository/room_location_repository_impl.dart';
import 'package:roomio/features/room/domain/entities/room_location_error.dart';

class TestGeolocator extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requestedPermission = LocationPermission.whileInUse;
  int requests = 0;
  int positionCalls = 0;
  LocationSettings? usedSettings;
  Exception? failure;
  final opened = <RoomLocationSettings>[];

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return requestedPermission;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    positionCalls++;
    usedSettings = locationSettings;
    if (failure != null) throw failure!;
    return Position(
      latitude: 10.8,
      longitude: 106.7,
      timestamp: DateTime(2026),
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  @override
  Future<bool> openAppSettings() async {
    opened.add(RoomLocationSettings.app);
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    opened.add(RoomLocationSettings.location);
    return true;
  }
}

class TestGeocoder implements geo.Geocoding {
  List<geo.Location> results = [
    const geo.Location(latitude: 10.8, longitude: 106.7),
  ];
  String? query;
  Exception? failure;
  int reverseCalls = 0;
  @override
  Future<List<geo.Location>> locationFromAddress(
    String address, {
    Locale? locale,
  }) async {
    query = address;
    if (failure != null) throw failure!;
    return results;
  }

  @override
  Future<List<geo.Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude, {
    Locale? locale,
  }) async {
    reverseCalls++;
    return [
      geo.Placemark(
        name: 'Địa điểm $latitude',
        administrativeArea: 'Hồ Chí Minh',
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late TestGeolocator gps;
  late TestGeocoder geocoder;
  late RoomLocationRepositoryImpl repository;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    gps = TestGeolocator();
    geocoder = TestGeocoder();
    repository = RoomLocationRepositoryImpl(
      RoomLocationDataSource(geolocator: gps, geocoderFactory: () => geocoder),
    );
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  Matcher issue(RoomLocationIssue value) => throwsA(
    isA<RoomLocationException>().having((error) => error.issue, 'issue', value),
  );

  test(
    'GPS requests denied permission then obtains real platform coordinates',
    () async {
      gps.permission = LocationPermission.denied;
      final result = await repository.getCurrentLocation();
      expect(gps.requests, 1);
      expect(result.latitude, 10.8);
      expect(result.longitude, 106.7);
      expect(gps.usedSettings!.accuracy, LocationAccuracy.high);
      expect(gps.usedSettings!.timeLimit, const Duration(seconds: 20));
    },
  );

  test('disabled GPS does not request permission or position', () async {
    gps.enabled = false;
    await expectLater(
      repository.getCurrentLocation(),
      issue(RoomLocationIssue.serviceDisabled),
    );
    expect(gps.requests, 0);
    expect(gps.positionCalls, 0);
  });

  test(
    'permanent permission denial is actionable without another native prompt',
    () async {
      gps.permission = LocationPermission.deniedForever;
      await expectLater(
        repository.getCurrentLocation(),
        issue(RoomLocationIssue.permissionDeniedForever),
      );
      expect(gps.requests, 0);
      expect(gps.positionCalls, 0);
    },
  );

  test('denied permission after prompt does not access GPS', () async {
    gps.permission = LocationPermission.denied;
    gps.requestedPermission = LocationPermission.denied;
    await expectLater(
      repository.getCurrentLocation(),
      issue(RoomLocationIssue.permissionDenied),
    );
    expect(gps.positionCalls, 0);
  });

  test('GPS timeout becomes a domain error', () async {
    gps.failure = TimeoutException('timeout');
    await expectLater(
      repository.getCurrentLocation(),
      issue(RoomLocationIssue.timeout),
    );
  });

  test(
    'geocoding trims the address and maps coordinates without asking GPS permission',
    () async {
      final result = await repository.searchLocations('  Thủ Đức  ');
      expect(geocoder.query, 'Thủ Đức');
      expect(result.single.name, 'Thủ Đức');
      expect(result.single.latitude, 10.8);
      expect(gps.requests, 0);
      expect(gps.positionCalls, 0);
      expect(geocoder.reverseCalls, 0);
    },
  );

  test(
    'geocoding deduplicates coordinates and labels ambiguous results',
    () async {
      geocoder.results = [
        const geo.Location(latitude: 10, longitude: 106),
        const geo.Location(latitude: 10, longitude: 106),
        const geo.Location(latitude: 11, longitude: 107),
      ];
      final result = await repository.searchLocations('Thủ Đức');
      expect(result.length, 2);
      expect(result.first.name, contains('Địa điểm 10.0'));
      expect(result.last.name, contains('Địa điểm 11.0'));
    },
  );

  test('empty geocoding response becomes addressNotFound', () async {
    geocoder.results = [];
    await expectLater(
      repository.searchLocations('Unknown'),
      issue(RoomLocationIssue.addressNotFound),
    );
  });

  test(
    'geocoding network/platform failures become a recoverable domain error',
    () async {
      geocoder.failure = PlatformException(code: 'IO_ERROR');
      await expectLater(
        repository.searchLocations('Thủ Đức'),
        issue(RoomLocationIssue.unavailable),
      );
    },
  );

  test(
    'unsupported geocoding platform is reported without native calls',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await expectLater(
        repository.searchLocations('Thủ Đức'),
        issue(RoomLocationIssue.unsupported),
      );
      expect(geocoder.query, isNull);
    },
  );

  test('settings actions open the appropriate device page', () async {
    await repository.openSettings(RoomLocationSettings.app);
    await repository.openSettings(RoomLocationSettings.location);
    expect(gps.opened, [
      RoomLocationSettings.app,
      RoomLocationSettings.location,
    ]);
  });

  test(
    'reverse geocoding replaces GPS label while preserving coordinates',
    () async {
      final coordinates = await repository.getCurrentLocation();
      final address = await repository.reverseGeocode(coordinates);
      expect(address.name, contains('Địa điểm 10.8'));
      expect(address.name, contains('Hồ Chí Minh'));
      expect(address.latitude, coordinates.latitude);
      expect(address.longitude, coordinates.longitude);
      expect(geocoder.reverseCalls, 1);
    },
  );
}
