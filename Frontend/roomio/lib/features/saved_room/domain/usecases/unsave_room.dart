import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/saved_room/domain/repository/save_room_repository.dart';

class UnsaveRoomUseCase extends UseCase<DataState<String>, String> {
  final SaveRoomRepository _repository;
  UnsaveRoomUseCase(this._repository);

  @override
  Future<DataState<String>> call(String params) =>
      _repository.unsaveRoom(params);
}
