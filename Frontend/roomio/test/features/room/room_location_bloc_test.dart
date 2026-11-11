import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomio/features/room/domain/entities/room_location_error.dart';
import 'package:roomio/features/room/domain/entities/room_sub_entities.dart';
import 'package:roomio/features/room/domain/usecases/tenant/get_current_room_location.dart';
import 'package:roomio/features/room/domain/usecases/tenant/search_room_locations.dart';
import 'package:roomio/features/room/domain/usecases/tenant/open_room_location_settings.dart';
import 'package:roomio/features/room/domain/usecases/tenant/search_room_by_position.dart';
import 'package:roomio/features/room/domain/usecases/tenant/search_rooms_by_area.dart';
import 'package:roomio/features/room/domain/usecases/tenant/get_location_suggestions.dart';
import 'package:roomio/features/room/presentation/bloc/remote/tenant/remote_tenant_room_bloc.dart';
import 'package:roomio/features/room/presentation/bloc/remote/tenant/remote_tenant_room_event.dart';
import 'package:roomio/features/room/presentation/bloc/remote/tenant/remote_tenant_room_state.dart';
import 'room_test_support.dart';
import 'room_location_test_support.dart';

void main() {
  late RoomTestApi api;
  late FakeRoomLocationRepository device;
  late RemoteTenantRoomBloc bloc;
  setUp(() {
    api = RoomTestApi()
      ..responseData = {
        'rooms': [nearbyJson],
      };
    device = FakeRoomLocationRepository();
    bloc = RemoteTenantRoomBloc(
      SearchRoomByPositionUseCase(api.repository),
      SearchRoomsByAreaUseCase(api.repository),
      GetCurrentRoomLocationUseCase(device),
      SearchRoomLocationsUseCase(device),
      OpenRoomLocationSettingsUseCase(device),
      GetLocationSuggestionsUseCase(api.repository),
    );
  });
  tearDown(() async {
    await bloc.close();
    api.dispose();
  });

  Future<void> search(RemoteTenantRoomEvent event) async {
    final done = bloc.stream.firstWhere(
      (state) =>
          state is RemoteSearchRoomsSuccess ||
          state is RemoteRoomLocationFailure ||
          state is RemoteRoomLocationChoices,
    );
    bloc.add(event);
    await done;
  }

  test('GPS determines position then automatically calls nearby API', () async {
    final states = <RemoteTenantRoomState>[];
    final sub = bloc.stream.listen(states.add);
    await search(const SearchRoomsNearMeEvent(radius: 5));
    expect(device.gpsCalls, 1);
    expect(states, [
      isA<RemoteDeterminingRoomLocation>(),
      isA<RemoteTenantRoomLoading>(),
      isA<RemoteSearchRoomsSuccess>(),
    ]);
    expect(api.requests.single.queryParameters, {
      'latitude': 10.8,
      'longitude': 106.7,
      'radius': 5.0,
    });
    expect(
      (bloc.state as RemoteSearchRoomsSuccess).location,
      FakeRoomLocationRepository.location,
    );
    await sub.cancel();
  });

  for (final issue in [
    RoomLocationIssue.permissionDenied,
    RoomLocationIssue.permissionDeniedForever,
    RoomLocationIssue.serviceDisabled,
    RoomLocationIssue.timeout,
  ]) {
    test('GPS $issue never calls room API', () async {
      device.failure = issue;
      await search(const SearchRoomsNearMeEvent());
      expect(bloc.state, RemoteRoomLocationFailure(issue: issue));
      expect(api.requests, isEmpty);
    });
  }

  test('typed address geocodes before calling nearby API', () async {
    await search(
      const SearchRoomsByAddressEvent(address: 'Thủ Đức', radius: 3),
    );
    expect(device.queries, ['Thủ Đức']);
    expect(api.requests.single.queryParameters['radius'], 3);
  });

  test('multiple addresses wait for user selection', () async {
    device.search = (_) async => [
      FakeRoomLocationRepository.location,
      const LocationEntity(name: 'Thủ Đức 2', latitude: 11, longitude: 107),
    ];
    await search(const SearchRoomsByAddressEvent(address: 'Thủ Đức'));
    expect(bloc.state, isA<RemoteRoomLocationChoices>());
    expect(api.requests, isEmpty);
    await search(
      SearchRoomsAtLocationEvent(
        location: (bloc.state as RemoteRoomLocationChoices).locations.last,
        radius: 20,
      ),
    );
    expect(api.requests.single.queryParameters, {
      'latitude': 11.0,
      'longitude': 107.0,
      'radius': 20.0,
    });
  });

  test(
    'not found address produces recovery without requesting rooms',
    () async {
      device.search = (_) async => [];
      await search(const SearchRoomsByAddressEvent(address: 'Unknown'));
      expect(
        bloc.state,
        const RemoteRoomLocationFailure(
          issue: RoomLocationIssue.addressNotFound,
        ),
      );
      expect(api.requests, isEmpty);
    },
  );

  test(
    'slow old geocoding cannot overwrite the latest location search',
    () async {
      final old = Completer<List<LocationEntity>>();
      device.search = (query) => query == 'Old'
          ? old.future
          : Future.value([FakeRoomLocationRepository.location]);
      final resolving = bloc.stream.firstWhere(
        (state) => state is RemoteResolvingRoomAddress,
      );
      bloc.add(const SearchRoomsByAddressEvent(address: 'Old'));
      await resolving;
      await search(const SearchRoomsByAddressEvent(address: 'New'));
      old.complete([
        const LocationEntity(name: 'Old', latitude: 1, longitude: 2),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(api.requests.length, 1);
      expect(api.requests.single.queryParameters['latitude'], 10.8);
      expect(
        (bloc.state as RemoteSearchRoomsSuccess).location!.name,
        'Thủ Đức',
      );
    },
  );

  test(
    'typing cancels pending GPS result and prevents automatic room search',
    () async {
      final gps = Completer<LocationEntity>();
      device.current = () => gps.future;
      final determining = bloc.stream.firstWhere(
        (state) => state is RemoteDeterminingRoomLocation,
      );
      bloc.add(const SearchRoomsNearMeEvent());
      await determining;
      final reset = bloc.stream.firstWhere(
        (state) => state is RemoteTenantRoomInitial,
      );
      bloc.add(const ResetRoomLocationSearchEvent());
      await reset;
      gps.complete(FakeRoomLocationRepository.location);
      await Future<void>.delayed(Duration.zero);
      expect(api.requests, isEmpty);
      expect(bloc.state, const RemoteTenantRoomInitial());
    },
  );

  test('retry after denied permission reruns GPS and succeeds', () async {
    device.failure = RoomLocationIssue.permissionDenied;
    await search(const SearchRoomsNearMeEvent());
    device.failure = null;
    await search(const RetryRoomSearchEvent());
    expect(device.gpsCalls, 2);
    expect(api.requests.length, 1);
  });

  test('repeated GPS taps share one permission/location request', () async {
    final gps = Completer<LocationEntity>();
    device.current = () => gps.future;
    final determining = bloc.stream.firstWhere(
      (state) => state is RemoteDeterminingRoomLocation,
    );
    bloc.add(const SearchRoomsNearMeEvent());
    await determining;
    bloc.add(const SearchRoomsNearMeEvent(radius: 3));
    await Future<void>.delayed(Duration.zero);
    final done = bloc.stream.firstWhere(
      (state) => state is RemoteSearchRoomsSuccess,
    );
    gps.complete(FakeRoomLocationRepository.location);
    await done;
    expect(device.gpsCalls, 1);
    expect(api.requests.single.queryParameters['radius'], 3);
  });
}
