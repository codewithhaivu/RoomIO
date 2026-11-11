import 'dart:async';
import 'package:roomio/features/room/domain/entities/room_sub_entities.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomio/features/room/domain/entities/room_location_error.dart';
import 'package:roomio/features/room/domain/entities/room_place_suggestion.dart';
import 'package:roomio/features/room/domain/usecases/landlord/autocomplete_room_address.dart';
import 'package:roomio/features/room/domain/usecases/landlord/resolve_room_place.dart';
import 'package:roomio/features/room/domain/usecases/landlord/reverse_room_location.dart';
import 'package:roomio/features/room/domain/usecases/tenant/get_current_room_location.dart';
import 'package:roomio/features/room/domain/usecases/tenant/open_room_location_settings.dart';
import 'package:roomio/features/room/presentation/bloc/remote/landlord/room_form_location_cubit.dart';
import 'room_location_test_support.dart';
import 'room_places_test_support.dart';

void main() {
  late FakeRoomPlacesRepository places;
  late FakeRoomLocationRepository gps;
  late RoomFormLocationCubit cubit;
  setUp(() {
    places = FakeRoomPlacesRepository();
    gps = FakeRoomLocationRepository();
    cubit = RoomFormLocationCubit(
      AutocompleteRoomAddressUseCase(places),
      ResolveRoomPlaceUseCase(places),
      GetCurrentRoomLocationUseCase(gps),
      ReverseRoomLocationUseCase(gps),
      OpenRoomLocationSettingsUseCase(gps),
      debounce: const Duration(milliseconds: 10),
    );
  });
  tearDown(() => cubit.close());

  Future<void> suggest(String query) async {
    final done = cubit.stream.firstWhere(
      (state) => state.status == RoomFormLocationStatus.idle,
    );
    cubit.queryChanged(query);
    await done;
  }

  test('editing prefills location without any places request', () {
    cubit.initialize(FakeRoomPlacesRepository.selected);
    expect(cubit.state.query, FakeRoomPlacesRepository.selected.name);
    expect(cubit.state.location, FakeRoomPlacesRepository.selected);
    expect(places.queries, isEmpty);
  });

  test('debounce only requests suggestions for latest text', () async {
    cubit.queryChanged('Võ V');
    cubit.queryChanged('Võ Văn');
    await suggest('Võ Văn Ngân');
    expect(places.queries, ['Võ Văn Ngân']);
  });

  test('short query clears suggestions and coordinates immediately', () {
    cubit.initialize(FakeRoomPlacesRepository.selected);
    cubit.queryChanged('12');
    expect(cubit.state.location, isNull);
    expect(cubit.state.suggestions, isEmpty);
    expect(places.queries, isEmpty);
  });

  test(
    'selection resolves the chosen place ID and updates address and coordinates',
    () async {
      await suggest('Võ Văn');
      await cubit.selectSuggestion(cubit.state.suggestions.single);
      expect(cubit.state.location, FakeRoomPlacesRepository.selected);
      expect(cubit.state.query, FakeRoomPlacesRepository.selected.name);
      expect(places.resolved, [FakeRoomPlacesRepository.suggestion.placeId]);
      await suggest('Other road');
      expect(cubit.state.location, isNull);
    },
  );

  test(
    'changing chosen address invalidates coordinates before debounce',
    () async {
      cubit.initialize(FakeRoomPlacesRepository.selected);
      cubit.queryChanged('Another street');
      expect(cubit.state.location, isNull);
      expect(cubit.state.query, 'Another street');
    },
  );

  test(
    'GPS sets the reverse geocoded street and the same coordinates atomically',
    () async {
      await cubit.useCurrentLocation();
      expect(cubit.state.location!.name, '12 Đường Võ Văn Ngân, Thủ Đức');
      expect(cubit.state.location!.latitude, 10.8);
      expect(cubit.state.location!.longitude, 106.7);
      expect(cubit.state.query, cubit.state.location!.name);
      expect(places.queries, isEmpty);
    },
  );

  test(
    'failed reverse geocoding does not retain old or partial coordinates',
    () async {
      cubit.initialize(FakeRoomPlacesRepository.selected);
      gps.reverse = (_) async =>
          throw const RoomLocationException(RoomLocationIssue.addressNotFound);
      await cubit.useCurrentLocation();
      expect(cubit.state.location, isNull);
      expect(cubit.state.error, isNotNull);
    },
  );

  test(
    'missing key reports unavailable suggestions while GPS remains usable',
    () async {
      places.failure = RoomPlacesIssue.configuration;
      await suggest('Võ Văn');
      expect(cubit.state.error, contains('chưa sẵn sàng'));
      expect(cubit.state.location, isNull);
      await cubit.useCurrentLocation();
      expect(cubit.state.location, isNotNull);
    },
  );

  test('old suggestions cannot overwrite a newer query', () async {
    final old = Completer<List<RoomPlaceSuggestion>>();
    places.suggestionsFor = (query) => query == 'Old road'
        ? old.future
        : Future.value([FakeRoomPlacesRepository.suggestion]);
    cubit.queryChanged('Old road');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await suggest('New road');
    old.complete([]);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.query, 'New road');
    expect(cubit.state.suggestions, isNotEmpty);
  });

  test(
    'late details cannot restore coordinates after user edits the address',
    () async {
      final detail = Completer<LocationEntity>();
      places.locationFor = (_) => detail.future;
      await suggest('Old road');
      final selecting = cubit.selectSuggestion(cubit.state.suggestions.single);
      cubit.queryChanged('New road');
      detail.complete(FakeRoomPlacesRepository.selected);
      await selecting;
      expect(cubit.state.query, 'New road');
      expect(cubit.state.location, isNull);
    },
  );

  test('closing cancels debounced requests', () async {
    cubit.queryChanged('Võ Văn');
    await cubit.close();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(places.queries, isEmpty);
  });

  test('a failed older request cannot overwrite newer suggestions', () async {
    final old = Completer<List<RoomPlaceSuggestion>>();
    places.suggestionsFor = (query) => query == 'Old road'
        ? old.future
        : Future.value([FakeRoomPlacesRepository.suggestion]);
    cubit.queryChanged('Old road');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await suggest('New road');
    old.completeError(const RoomPlacesException(RoomPlacesIssue.unavailable));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.query, 'New road');
    expect(cubit.state.suggestions, isNotEmpty);
    expect(cubit.state.error, isNull);
  });

  test(
    'failed place detail keeps the selected text without stale coordinates',
    () async {
      await suggest('Võ Văn Ngân');
      places.failure = RoomPlacesIssue.denied;
      await cubit.selectSuggestion(cubit.state.suggestions.single);
      expect(
        cubit.state.query,
        FakeRoomPlacesRepository.suggestion.description,
      );
      expect(cubit.state.location, isNull);
      expect(cubit.state.status, RoomFormLocationStatus.idle);
      expect(cubit.state.error, isNotNull);
    },
  );
}
