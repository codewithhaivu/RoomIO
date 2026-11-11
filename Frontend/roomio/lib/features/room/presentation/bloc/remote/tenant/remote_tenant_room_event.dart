import 'package:equatable/equatable.dart';
import 'package:roomio/features/room/domain/entities/room_request_entities.dart';
import 'package:roomio/features/room/domain/entities/room_sub_entities.dart';
import 'package:roomio/features/room/domain/entities/room_location_error.dart';

abstract class RemoteTenantRoomEvent extends Equatable {
  const RemoteTenantRoomEvent();

  @override
  List<Object?> get props => [];
}

class SearchRoomByPositionEvent extends RemoteTenantRoomEvent {
  final SearchRoomByPositionRequestEntity request;

  const SearchRoomByPositionEvent({required this.request});

  @override
  List<Object?> get props => [request];
}

class GetLocationSuggestionsEvent extends RemoteTenantRoomEvent {
  const GetLocationSuggestionsEvent();
}

class SearchRoomsByAreaEvent extends RemoteTenantRoomEvent {
  final SearchRoomsByAreaRequestEntity request;

  const SearchRoomsByAreaEvent({required this.request});

  @override
  List<Object?> get props => [request];
}

class SearchRoomsNearMeEvent extends RemoteTenantRoomEvent {
  final double radius;
  const SearchRoomsNearMeEvent({this.radius = 10});
  @override
  List<Object?> get props => [radius];
}

class SearchRoomsByAddressEvent extends RemoteTenantRoomEvent {
  final String address;
  final double radius;
  const SearchRoomsByAddressEvent({required this.address, this.radius = 10});
  @override
  List<Object?> get props => [address, radius];
}

class SearchRoomsAtLocationEvent extends RemoteTenantRoomEvent {
  final LocationEntity location;
  final double radius;
  const SearchRoomsAtLocationEvent({required this.location, this.radius = 10});
  @override
  List<Object?> get props => [location, radius];
}

class ResetRoomLocationSearchEvent extends RemoteTenantRoomEvent {
  const ResetRoomLocationSearchEvent();
}

class RetryRoomSearchEvent extends RemoteTenantRoomEvent {
  const RetryRoomSearchEvent();
}

class OpenRoomLocationSettingsEvent extends RemoteTenantRoomEvent {
  final RoomLocationSettings settings;
  const OpenRoomLocationSettingsEvent({required this.settings});
  @override
  List<Object?> get props => [settings];
}
