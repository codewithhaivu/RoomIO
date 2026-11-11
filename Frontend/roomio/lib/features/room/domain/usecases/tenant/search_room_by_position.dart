import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/room/domain/entities/nearby_room_entities.dart';
import 'package:roomio/features/room/domain/entities/room_request_entities.dart';
import 'package:roomio/features/room/domain/repository/room_repository.dart';

class SearchRoomByPositionUseCase
    extends
        UseCase<
          DataState<List<NearbyRoomEntity>>,
          SearchRoomByPositionRequestEntity
        > {
  final RoomRepository _roomRepository;

  SearchRoomByPositionUseCase(this._roomRepository);

  @override
  Future<DataState<List<NearbyRoomEntity>>> call(
    SearchRoomByPositionRequestEntity params,
  ) async {
    return await _roomRepository.searchRoomByPosition(
      params.latitude,
      params.longitude,
      params.radius,
    );
  }
}
