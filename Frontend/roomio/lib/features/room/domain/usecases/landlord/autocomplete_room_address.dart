import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/room/domain/entities/room_place_suggestion.dart';
import 'package:roomio/features/room/domain/repository/room_places_repository.dart';

class AutocompleteRoomAddressParams {
  final String query;
  const AutocompleteRoomAddressParams(this.query);
}

class AutocompleteRoomAddressUseCase
    extends UseCase<List<RoomPlaceSuggestion>, AutocompleteRoomAddressParams> {
  final RoomPlacesRepository _repository;
  AutocompleteRoomAddressUseCase(this._repository);
  @override
  Future<List<RoomPlaceSuggestion>> call(
    AutocompleteRoomAddressParams params,
  ) => _repository.autocomplete(params.query);
}
