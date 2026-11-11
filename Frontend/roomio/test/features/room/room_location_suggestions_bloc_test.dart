import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/room/domain/entities/room_place_suggestion.dart';
import 'package:roomio/features/room/domain/usecases/tenant/get_current_room_location.dart';
import 'package:roomio/features/room/domain/usecases/tenant/get_location_suggestions.dart';
import 'package:roomio/features/room/domain/usecases/tenant/open_room_location_settings.dart';
import 'package:roomio/features/room/domain/usecases/tenant/search_room_by_position.dart';
import 'package:roomio/features/room/domain/usecases/tenant/search_room_locations.dart';
import 'package:roomio/features/room/domain/usecases/tenant/search_rooms_by_area.dart';
import 'package:roomio/features/room/presentation/bloc/remote/tenant/remote_tenant_room_bloc.dart';
import 'package:roomio/features/room/presentation/bloc/remote/tenant/remote_tenant_room_event.dart';
import 'package:roomio/features/room/presentation/bloc/remote/tenant/remote_tenant_room_state.dart';
import 'room_location_test_support.dart';
import 'room_test_support.dart';

class PendingSuggestionsUseCase extends GetLocationSuggestionsUseCase {
  final pending = Completer<DataState<List<LocationSuggestion>>>();
  int calls = 0;
  PendingSuggestionsUseCase(super.repository);

  @override
  Future<DataState<List<LocationSuggestion>>> call(void params) {
    calls++;
    return pending.future;
  }
}

void main() {
  late RoomTestApi api;
  late RemoteTenantRoomBloc bloc;

  RemoteTenantRoomBloc createBloc(GetLocationSuggestionsUseCase suggestions) {
    final device = FakeRoomLocationRepository();
    return RemoteTenantRoomBloc(
      SearchRoomByPositionUseCase(api.repository),
      SearchRoomsByAreaUseCase(api.repository),
      GetCurrentRoomLocationUseCase(device),
      SearchRoomLocationsUseCase(device),
      OpenRoomLocationSettingsUseCase(device),
      suggestions,
    );
  }

  setUp(() {
    api = RoomTestApi()
      ..responseData = {
        'data': [
          {'location_id': 'thu-duc-id', 'name_district': 'Thủ Đức'},
        ],
      };
    bloc = createBloc(GetLocationSuggestionsUseCase(api.repository));
  });
  tearDown(() async {
    await bloc.close();
    api.dispose();
  });

  test(
    'loads API suggestions and keeps cache after resetting search',
    () async {
      final states = <RemoteTenantRoomState>[];
      final sub = bloc.stream.listen(states.add);
      final loaded = bloc.stream.firstWhere(
        (state) => state is RemoteLocationSuggestionsSuccess,
      );
      bloc.add(const GetLocationSuggestionsEvent());
      final result = await loaded as RemoteLocationSuggestionsSuccess;
      expect(states, [
        isA<RemoteLocationSuggestionsLoading>(),
        isA<RemoteLocationSuggestionsSuccess>(),
      ]);
      expect(result.locations.single.nameDistrict, 'Thủ Đức');
      final reset = bloc.stream.firstWhere((s) => s is RemoteTenantRoomInitial);
      bloc.add(const ResetRoomLocationSearchEvent());
      await reset;
      expect(bloc.locationSuggestionsState, same(result));
      bloc.add(const GetLocationSuggestionsEvent());
      await Future<void>.delayed(Duration.zero);
      expect(api.requests.length, 1);
      await sub.cancel();
    },
  );

  test('API failure emits failure and can retry successfully', () async {
    final error = DioException(
      requestOptions: RequestOptions(path: '/locations'),
      type: DioExceptionType.connectionError,
    );
    api.error = error;
    final failed = bloc.stream.firstWhere(
      (state) => state is RemoteLocationSuggestionsFailure,
    );
    bloc.add(const GetLocationSuggestionsEvent());
    expect((await failed as RemoteLocationSuggestionsFailure).dio, same(error));
    api.error = null;
    api.responseData = {'data': []};
    final loaded = bloc.stream.firstWhere(
      (state) => state is RemoteLocationSuggestionsSuccess,
    );
    bloc.add(const GetLocationSuggestionsEvent());
    expect(
      (await loaded as RemoteLocationSuggestionsSuccess).locations,
      isEmpty,
    );
    expect(api.requests.length, 2);
  });

  test(
    'late suggestions preserve search results and do not duplicate loads',
    () async {
      await bloc.close();
      final suggestions = PendingSuggestionsUseCase(api.repository);
      bloc = createBloc(suggestions);
      final loading = bloc.stream.firstWhere(
        (state) => state is RemoteLocationSuggestionsLoading,
      );
      bloc.add(const GetLocationSuggestionsEvent());
      await loading;
      bloc.add(const GetLocationSuggestionsEvent());
      api.responseData = {
        'rooms': [nearbyJson],
      };
      final searched = bloc.stream.firstWhere(
        (state) => state is RemoteSearchRoomsSuccess,
      );
      bloc.add(const SearchRoomsNearMeEvent(radius: 5));
      final searchResult = await searched;
      final loaded = bloc.stream.firstWhere(
        (state) => state is RemoteLocationSuggestionsSuccess,
      );
      suggestions.pending.complete(const DataSuccess([]));
      final result = await loaded as RemoteLocationSuggestionsSuccess;
      expect(result.searchState, same(searchResult));
      expect(suggestions.calls, 1);
      expect(api.requests.single.path, '/nearby/position');
    },
  );
}
