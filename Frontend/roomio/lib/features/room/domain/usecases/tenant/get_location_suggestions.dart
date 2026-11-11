import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/room/domain/entities/room_place_suggestion.dart';
import 'package:roomio/features/room/domain/repository/room_repository.dart';

class GetLocationSuggestionsUseCase
    extends UseCase<DataState<List<LocationSuggestion>>, void> {
  final RoomRepository _roomRepository;

  GetLocationSuggestionsUseCase(this._roomRepository);

  @override
  Future<DataState<List<LocationSuggestion>>> call(void params) async {
    return await _roomRepository.getLocationSuggestion();
  }
}
