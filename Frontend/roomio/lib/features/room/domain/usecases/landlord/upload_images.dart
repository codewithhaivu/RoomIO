import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/room/domain/entities/room_sub_entities.dart';
import 'package:roomio/features/room/domain/entities/room_request_entities.dart';
import 'package:roomio/features/room/domain/repository/room_repository.dart';

class UploadRoomImagesUseCase
    extends
        UseCase<
          DataState<List<RoomImageEntity>>,
          UploadRoomImagesRequestEntity
        > {
  final RoomRepository _roomRepository;

  UploadRoomImagesUseCase(this._roomRepository);

  @override
  Future<DataState<List<RoomImageEntity>>> call(
    UploadRoomImagesRequestEntity params,
  ) async {
    return await _roomRepository.uploadImages(
      params.images,
      params.isThumbnails,
    );
  }
}
