import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:roomio/features/room/domain/entities/nearby_room_entities.dart';
import 'package:roomio/features/room/domain/entities/room_sub_entities.dart';
import 'package:roomio/features/room/domain/entities/room_location_error.dart';
import 'package:roomio/features/room/domain/entities/room_place_suggestion.dart';

abstract class RemoteTenantRoomState extends Equatable {
  const RemoteTenantRoomState();

  @override
  List<Object?> get props => [];
}

class RemoteTenantRoomInitial extends RemoteTenantRoomState {
  const RemoteTenantRoomInitial();
}

// Loading suggestions must preserve a concurrent GPS/address/room search.
abstract class RemoteLocationSuggestionsState extends RemoteTenantRoomState {
  final RemoteTenantRoomState searchState;
  const RemoteLocationSuggestionsState({required this.searchState});

  @override
  List<Object?> get props => [searchState];
}

class RemoteLocationSuggestionsLoading extends RemoteLocationSuggestionsState {
  const RemoteLocationSuggestionsLoading({required super.searchState});
}

class RemoteLocationSuggestionsSuccess extends RemoteLocationSuggestionsState {
  final List<LocationSuggestion> locations;
  const RemoteLocationSuggestionsSuccess({
    required super.searchState,
    required this.locations,
  });

  @override
  List<Object?> get props => [searchState, locations];
}

class RemoteLocationSuggestionsFailure extends RemoteLocationSuggestionsState {
  final DioException dio;
  const RemoteLocationSuggestionsFailure({
    required super.searchState,
    required this.dio,
  });

  @override
  List<Object?> get props => [searchState, dio];
}

class RemoteTenantRoomLoading extends RemoteTenantRoomState {
  const RemoteTenantRoomLoading();
}

class RemoteSearchRoomsSuccess extends RemoteTenantRoomState {
  final List<NearbyRoomEntity> rooms;
  final LocationEntity? location;
  final double? radius;

  const RemoteSearchRoomsSuccess({
    required this.rooms,
    this.location,
    this.radius,
  });

  @override
  List<Object?> get props => [rooms, location, radius];
}

class RemoteTenantRoomFailure extends RemoteTenantRoomState {
  final DioException dio;

  const RemoteTenantRoomFailure({required this.dio});

  @override
  List<Object?> get props => [dio];
}

class RemoteDeterminingRoomLocation extends RemoteTenantRoomState {
  const RemoteDeterminingRoomLocation();
}

class RemoteResolvingRoomAddress extends RemoteTenantRoomState {
  final String address;
  const RemoteResolvingRoomAddress({required this.address});
  @override
  List<Object?> get props => [address];
}

class RemoteRoomLocationChoices extends RemoteTenantRoomState {
  final List<LocationEntity> locations;
  final double radius;
  const RemoteRoomLocationChoices({
    required this.locations,
    required this.radius,
  });
  @override
  List<Object?> get props => [locations, radius];
}

class RemoteRoomLocationFailure extends RemoteTenantRoomState {
  final RoomLocationIssue issue;
  const RemoteRoomLocationFailure({required this.issue});
  @override
  List<Object?> get props => [issue];
}
