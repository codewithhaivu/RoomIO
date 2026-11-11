import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/room/domain/entities/room_location_error.dart';
import 'package:roomio/features/room/domain/entities/room_place_suggestion.dart';
import 'package:roomio/features/room/domain/entities/room_request_entities.dart';
import 'package:roomio/features/room/domain/entities/room_sub_entities.dart';
import 'package:roomio/features/room/domain/usecases/tenant/search_room_by_position.dart';
import 'package:roomio/features/room/domain/usecases/tenant/get_location_suggestions.dart';
import 'package:roomio/features/room/domain/usecases/tenant/search_rooms_by_area.dart';
import 'package:roomio/features/room/domain/usecases/tenant/get_current_room_location.dart';
import 'package:roomio/features/room/domain/usecases/tenant/search_room_locations.dart';
import 'package:roomio/features/room/domain/usecases/tenant/open_room_location_settings.dart';
import 'package:roomio/features/room/presentation/bloc/remote/tenant/remote_tenant_room_event.dart';
import 'package:roomio/features/room/presentation/bloc/remote/tenant/remote_tenant_room_state.dart';

class RemoteTenantRoomBloc
    extends Bloc<RemoteTenantRoomEvent, RemoteTenantRoomState> {
  final SearchRoomByPositionUseCase _searchRoomByPositionUseCase;
  final SearchRoomsByAreaUseCase _searchRoomsByAreaUseCase;
  final GetCurrentRoomLocationUseCase _getCurrentRoomLocationUseCase;
  final SearchRoomLocationsUseCase _searchRoomLocationsUseCase;
  final OpenRoomLocationSettingsUseCase _openRoomLocationSettingsUseCase;
  final GetLocationSuggestionsUseCase _getLocationSuggestionsUseCase;
  RemoteLocationSuggestionsState? _locationSuggestionsState;

  RemoteLocationSuggestionsState? get locationSuggestionsState =>
      _locationSuggestionsState;
  int _operationId = 0;
  Future<LocationEntity>? _pendingGps;
  RemoteTenantRoomEvent? _lastSearch;

  RemoteTenantRoomBloc(
    this._searchRoomByPositionUseCase,
    this._searchRoomsByAreaUseCase,
    this._getCurrentRoomLocationUseCase,
    this._searchRoomLocationsUseCase,
    this._openRoomLocationSettingsUseCase,
    this._getLocationSuggestionsUseCase,
  ) : super(const RemoteTenantRoomInitial()) {
    on<GetLocationSuggestionsEvent>(_getLocationSuggestions);
    on<SearchRoomByPositionEvent>(searchRoomByPosition);
    on<SearchRoomsByAreaEvent>(searchRoomsByArea);
    on<SearchRoomsNearMeEvent>(_searchNearMe);
    on<SearchRoomsByAddressEvent>(_searchAddress);
    on<SearchRoomsAtLocationEvent>(_searchLocation);
    on<ResetRoomLocationSearchEvent>((event, emit) {
      _operationId++;
      _lastSearch = null;
      emit(const RemoteTenantRoomInitial());
    });
    on<RetryRoomSearchEvent>((event, emit) {
      final last = _lastSearch;
      if (last != null) add(last);
    });
    on<OpenRoomLocationSettingsEvent>(_openSettings);
  }

  RemoteTenantRoomState get _searchState {
    final current = state;
    return current is RemoteLocationSuggestionsState
        ? current.searchState
        : current;
  }

  Future<void> _getLocationSuggestions(
    GetLocationSuggestionsEvent event,
    Emitter<RemoteTenantRoomState> emit,
  ) async {
    if (_locationSuggestionsState is RemoteLocationSuggestionsLoading ||
        _locationSuggestionsState is RemoteLocationSuggestionsSuccess) {
      return;
    }
    final loading = RemoteLocationSuggestionsLoading(searchState: _searchState);
    _locationSuggestionsState = loading;
    emit(loading);
    final result = await _getLocationSuggestionsUseCase(null);
    if (emit.isDone) return;
    final next = result is DataSuccess<List<LocationSuggestion>>
        ? RemoteLocationSuggestionsSuccess(
            searchState: _searchState,
            locations: List.unmodifiable(result.data!),
          )
        : RemoteLocationSuggestionsFailure(
            searchState: _searchState,
            dio: result.error!,
          );
    _locationSuggestionsState = next;
    emit(next);
  }

  bool _active(int id, Emitter<RemoteTenantRoomState> emit) =>
      id == _operationId && !emit.isDone;

  Future<void> _searchPosition(
    SearchRoomByPositionRequestEntity request,
    int id,
    Emitter<RemoteTenantRoomState> emit, {
    LocationEntity? location,
  }) async {
    if (!_active(id, emit)) return;
    emit(const RemoteTenantRoomLoading());
    final result = await _searchRoomByPositionUseCase(request);
    if (!_active(id, emit)) return;
    if (result is DataSuccess) {
      emit(
        RemoteSearchRoomsSuccess(
          rooms: result.data!,
          location: location,
          radius: request.radius,
        ),
      );
    } else {
      emit(RemoteTenantRoomFailure(dio: result.error!));
    }
  }

  Future<void> searchRoomByPosition(
    SearchRoomByPositionEvent event,
    Emitter<RemoteTenantRoomState> emit,
  ) async {
    final id = ++_operationId;
    _lastSearch = event;
    await _searchPosition(event.request, id, emit);
  }

  Future<void> searchRoomsByArea(
    SearchRoomsByAreaEvent event,
    Emitter<RemoteTenantRoomState> emit,
  ) async {
    final id = ++_operationId;
    _lastSearch = event;
    emit(const RemoteTenantRoomLoading());
    final result = await _searchRoomsByAreaUseCase(event.request);
    if (!_active(id, emit)) return;
    if (result is DataSuccess) {
      emit(RemoteSearchRoomsSuccess(rooms: result.data!));
    } else {
      emit(RemoteTenantRoomFailure(dio: result.error!));
    }
  }

  Future<void> _searchNearMe(
    SearchRoomsNearMeEvent event,
    Emitter<RemoteTenantRoomState> emit,
  ) async {
    // Không mở nhiều hộp thoại xin quyền khi người dùng bấm liên tiếp.
    final id = ++_operationId;
    _lastSearch = event;
    emit(const RemoteDeterminingRoomLocation());
    try {
      final pending = _pendingGps ??= _getCurrentRoomLocationUseCase(null);
      late LocationEntity location;
      try {
        location = await pending;
      } finally {
        if (identical(_pendingGps, pending)) _pendingGps = null;
      }
      if (!_active(id, emit)) return;
      await _searchAt(location, event.radius, id, emit);
    } on RoomLocationException catch (error) {
      if (_active(id, emit)) {
        emit(RemoteRoomLocationFailure(issue: error.issue));
      }
    }
  }

  Future<void> _searchAddress(
    SearchRoomsByAddressEvent event,
    Emitter<RemoteTenantRoomState> emit,
  ) async {
    final id = ++_operationId;
    _lastSearch = event;
    emit(RemoteResolvingRoomAddress(address: event.address));
    try {
      final locations = await _searchRoomLocationsUseCase(event.address);
      if (!_active(id, emit)) return;
      if (locations.isEmpty) {
        emit(
          const RemoteRoomLocationFailure(
            issue: RoomLocationIssue.addressNotFound,
          ),
        );
      } else if (locations.length == 1) {
        await _searchAt(locations.first, event.radius, id, emit);
      } else {
        emit(
          RemoteRoomLocationChoices(locations: locations, radius: event.radius),
        );
      }
    } on RoomLocationException catch (error) {
      if (_active(id, emit)) {
        emit(RemoteRoomLocationFailure(issue: error.issue));
      }
    }
  }

  Future<void> _searchLocation(
    SearchRoomsAtLocationEvent event,
    Emitter<RemoteTenantRoomState> emit,
  ) async {
    final id = ++_operationId;
    _lastSearch = event;
    await _searchAt(event.location, event.radius, id, emit);
  }

  Future<void> _searchAt(
    LocationEntity location,
    double radius,
    int id,
    Emitter<RemoteTenantRoomState> emit,
  ) => _searchPosition(
    SearchRoomByPositionRequestEntity(
      latitude: location.latitude,
      longitude: location.longitude,
      radius: radius,
    ),
    id,
    emit,
    location: location,
  );

  Future<void> _openSettings(
    OpenRoomLocationSettingsEvent event,
    Emitter<RemoteTenantRoomState> emit,
  ) async {
    final id = _operationId;
    try {
      final opened = await _openRoomLocationSettingsUseCase(event.settings);
      if (!opened && _active(id, emit)) {
        emit(
          const RemoteRoomLocationFailure(issue: RoomLocationIssue.unavailable),
        );
      }
    } on RoomLocationException catch (error) {
      if (_active(id, emit)) {
        emit(RemoteRoomLocationFailure(issue: error.issue));
      }
    }
  }
}
