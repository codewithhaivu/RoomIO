import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/features/room/domain/entities/room_location_error.dart';
import 'package:roomio/features/room/domain/entities/room_place_suggestion.dart';
import 'package:roomio/features/room/domain/entities/room_sub_entities.dart';
import 'package:roomio/features/room/domain/usecases/landlord/autocomplete_room_address.dart';
import 'package:roomio/features/room/domain/usecases/landlord/resolve_room_place.dart';
import 'package:roomio/features/room/domain/usecases/landlord/reverse_room_location.dart';
import 'package:roomio/features/room/domain/usecases/tenant/get_current_room_location.dart';
import 'package:roomio/features/room/domain/usecases/tenant/open_room_location_settings.dart';

enum RoomFormLocationStatus { idle, suggesting, resolving, locating }

class RoomFormLocationState extends Equatable {
  final String query;
  final LocationEntity? location;
  final List<RoomPlaceSuggestion> suggestions;
  final RoomFormLocationStatus status;
  final String? error;
  final RoomLocationIssue? locationIssue;
  const RoomFormLocationState({
    this.query = '',
    this.location,
    this.suggestions = const [],
    this.status = RoomFormLocationStatus.idle,
    this.error,
    this.locationIssue,
  });
  bool get busy =>
      status == RoomFormLocationStatus.resolving ||
      status == RoomFormLocationStatus.locating;

  @override
  List<Object?> get props => [
    query,
    location,
    suggestions,
    status,
    error,
    locationIssue,
  ];
}

class RoomFormLocationCubit extends Cubit<RoomFormLocationState> {
  final AutocompleteRoomAddressUseCase _autocomplete;
  final ResolveRoomPlaceUseCase _resolve;
  final GetCurrentRoomLocationUseCase _currentLocation;
  final ReverseRoomLocationUseCase _reverse;
  final OpenRoomLocationSettingsUseCase _openSettings;
  final Duration debounce;
  Timer? _timer;
  int _revision = 0;
  Future<LocationEntity>? _pendingGps;

  RoomFormLocationCubit(
    this._autocomplete,
    this._resolve,
    this._currentLocation,
    this._reverse,
    this._openSettings, {
    this.debounce = const Duration(milliseconds: 350),
  }) : super(const RoomFormLocationState());

  void initialize(LocationEntity? location) {
    _timer?.cancel();
    _revision++;
    emit(
      RoomFormLocationState(query: location?.name ?? '', location: location),
    );
  }

  bool _active(int revision) => !isClosed && revision == _revision;

  void queryChanged(String query) {
    _timer?.cancel();
    final revision = ++_revision;
    final hasQuery = query.trim().length >= 3;
    // Gõ lại địa chỉ luôn hủy tọa độ cũ, kể cả khi tên mới trông gần giống.
    emit(
      RoomFormLocationState(
        query: query,
        status: hasQuery
            ? RoomFormLocationStatus.suggesting
            : RoomFormLocationStatus.idle,
      ),
    );
    if (!hasQuery) return;
    _timer = Timer(debounce, () => _loadSuggestions(query, revision));
  }

  Future<void> _loadSuggestions(String query, int revision) async {
    try {
      final suggestions = await _autocomplete(
        AutocompleteRoomAddressParams(query.trim()),
      );
      if (!_active(revision)) return;
      emit(
        RoomFormLocationState(
          query: query,
          suggestions: List.unmodifiable(suggestions),
          error: suggestions.isEmpty
              ? 'Chưa tìm thấy địa chỉ. Hãy nhập thêm tên đường hoặc phường.'
              : null,
        ),
      );
    } on RoomPlacesException catch (error) {
      if (_active(revision)) {
        emit(
          RoomFormLocationState(query: query, error: _placesError(error.issue)),
        );
      }
    }
  }

  Future<void> selectSuggestion(RoomPlaceSuggestion suggestion) async {
    _timer?.cancel();
    final revision = ++_revision;
    emit(
      RoomFormLocationState(
        query: suggestion.description,
        status: RoomFormLocationStatus.resolving,
      ),
    );
    try {
      final location = await _resolve(
        ResolveRoomPlaceParams(suggestion.placeId),
      );
      if (_active(revision)) {
        emit(RoomFormLocationState(query: location.name, location: location));
      }
    } on RoomPlacesException catch (error) {
      if (_active(revision)) {
        emit(
          RoomFormLocationState(
            query: suggestion.description,
            error: _placesError(error.issue),
          ),
        );
      }
    }
  }

  Future<void> useCurrentLocation() async {
    _timer?.cancel();
    final revision = ++_revision;
    final query = state.query;
    emit(
      RoomFormLocationState(
        query: query,
        status: RoomFormLocationStatus.locating,
      ),
    );
    try {
      final pending = _pendingGps ??= _currentLocation(null);
      late LocationEntity coordinates;
      try {
        coordinates = await pending;
      } finally {
        if (identical(pending, _pendingGps)) _pendingGps = null;
      }
      if (!_active(revision)) return;
      final location = await _reverse(coordinates);
      if (_active(revision)) {
        emit(RoomFormLocationState(query: location.name, location: location));
      }
    } on RoomLocationException catch (error) {
      if (_active(revision)) {
        emit(
          RoomFormLocationState(
            query: query,
            error: _locationError(error.issue),
            locationIssue: error.issue,
          ),
        );
      }
    }
  }

  Future<void> openSettings() async {
    final revision = _revision;
    try {
      final target = state.locationIssue == RoomLocationIssue.serviceDisabled
          ? RoomLocationSettings.location
          : RoomLocationSettings.app;
      final opened = await _openSettings(target);
      if (!opened && _active(revision)) {
        emit(
          RoomFormLocationState(
            query: state.query,
            error: 'Không thể mở cài đặt. Vui lòng mở cài đặt trên thiết bị.',
          ),
        );
      }
    } on RoomLocationException catch (error) {
      if (_active(revision)) {
        emit(
          RoomFormLocationState(
            query: state.query,
            error: _locationError(error.issue),
          ),
        );
      }
    }
  }

  String _placesError(RoomPlacesIssue issue) => switch (issue) {
    RoomPlacesIssue.configuration =>
      'Gợi ý địa chỉ chưa sẵn sàng. Bạn có thể sử dụng vị trí hiện tại.',
    RoomPlacesIssue.denied =>
      'Dịch vụ gợi ý địa chỉ chưa khả dụng. Bạn có thể sử dụng vị trí hiện tại.',
    RoomPlacesIssue.timeout => 'Tìm địa chỉ quá lâu. Vui lòng thử lại.',
    RoomPlacesIssue.notFound =>
      'Không xác định được địa chỉ này. Hãy chọn một gợi ý khác.',
    RoomPlacesIssue.unavailable =>
      'Không tải được gợi ý. Vui lòng kiểm tra kết nối và thử lại.',
  };
  String _locationError(RoomLocationIssue issue) => switch (issue) {
    RoomLocationIssue.serviceDisabled =>
      'GPS đang tắt. Hãy bật dịch vụ vị trí rồi thử lại.',
    RoomLocationIssue.permissionDenied =>
      'Bạn chưa cấp quyền vị trí. Hãy thử lại hoặc chọn địa chỉ từ gợi ý.',
    RoomLocationIssue.permissionDeniedForever =>
      'Quyền vị trí đang bị chặn. Hãy mở cài đặt để cấp lại quyền.',
    RoomLocationIssue.timeout =>
      'Xác định vị trí quá lâu. Vui lòng kiểm tra kết nối và thử lại.',
    RoomLocationIssue.addressNotFound =>
      'Chưa tìm được tên đường tại vị trí này. Hãy chọn địa chỉ từ gợi ý.',
    RoomLocationIssue.unsupported =>
      'Thiết bị này chưa hỗ trợ định vị. Hãy chọn địa chỉ từ gợi ý.',
    RoomLocationIssue.unavailable =>
      'Không lấy được địa chỉ hiện tại. Vui lòng kiểm tra kết nối và thử lại.',
  };

  @override
  Future<void> close() {
    _timer?.cancel();
    _revision++;
    return super.close();
  }
}
