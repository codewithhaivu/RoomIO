import 'package:equatable/equatable.dart';

class RoomPlaceSuggestion extends Equatable {
  final String placeId;
  final String description;
  const RoomPlaceSuggestion({required this.placeId, required this.description});

  @override
  List<Object?> get props => [placeId, description];
}

enum RoomPlacesIssue { configuration, unavailable, denied, timeout, notFound }

class RoomPlacesException implements Exception {
  final RoomPlacesIssue issue;
  const RoomPlacesException(this.issue);
}

class LocationSuggestion extends Equatable {
  final String locationId;
  final String nameDistrict;
  const LocationSuggestion({required this.locationId, required this.nameDistrict});

  @override
  List<Object?> get props => [locationId,nameDistrict];
}
