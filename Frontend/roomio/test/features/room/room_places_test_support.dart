import 'package:roomio/features/room/domain/entities/room_place_suggestion.dart';
import 'package:roomio/features/room/domain/entities/room_sub_entities.dart';
import 'package:roomio/features/room/domain/repository/room_places_repository.dart';

class FakeRoomPlacesRepository implements RoomPlacesRepository {
  static const suggestion = RoomPlaceSuggestion(
    placeId: 'place-id',
    description: '12 Võ Văn Ngân, Thủ Đức, Hồ Chí Minh',
  );
  static const selected = LocationEntity(
    name: '12 Võ Văn Ngân, Thủ Đức, Hồ Chí Minh',
    latitude: 10.85,
    longitude: 106.75,
  );
  final queries = <String>[];
  final resolved = <String>[];
  RoomPlacesIssue? failure;
  Future<List<RoomPlaceSuggestion>> Function(String)? suggestionsFor;
  Future<LocationEntity> Function(String)? locationFor;

  @override
  Future<List<RoomPlaceSuggestion>> autocomplete(String query) async {
    queries.add(query);
    if (failure != null) throw RoomPlacesException(failure!);
    return suggestionsFor == null ? [suggestion] : await suggestionsFor!(query);
  }

  @override
  Future<LocationEntity> resolvePlace(String placeId) async {
    resolved.add(placeId);
    if (failure != null) throw RoomPlacesException(failure!);
    return locationFor == null ? selected : await locationFor!(placeId);
  }
}
