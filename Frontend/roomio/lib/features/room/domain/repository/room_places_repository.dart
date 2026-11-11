import 'package:roomio/features/room/domain/entities/room_place_suggestion.dart';
import 'package:roomio/features/room/domain/entities/room_sub_entities.dart';

abstract class RoomPlacesRepository {
  Future<List<RoomPlaceSuggestion>> autocomplete(String query);
  Future<LocationEntity> resolvePlace(String placeId);
}
