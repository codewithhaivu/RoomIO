import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/room/domain/entities/nearby_room_entities.dart';
import 'package:roomio/features/room/domain/entities/room_request_entities.dart';
import 'package:roomio/features/room/domain/repository/room_repository.dart';

class SearchRoomsByAreaUseCase
    extends
        UseCase<
          DataState<List<NearbyRoomEntity>>,
          SearchRoomsByAreaRequestEntity
        > {
  final RoomRepository _roomRepository;

  SearchRoomsByAreaUseCase(this._roomRepository);

  @override
  Future<DataState<List<NearbyRoomEntity>>> call(
    SearchRoomsByAreaRequestEntity params,
  ) async {
    return await _roomRepository.searchRoomsByArea(
      params.locationId,
      params.district,
      radius: params.radius,
    );
  }
}
