import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/room/domain/entities/room_catalog_entity.dart';
import 'package:roomio/features/room/domain/repository/room_catalog_repository.dart';

class GetRoomCatalogUseCase
    extends UseCase<DataState<RoomCatalogEntity>, void> {
  final RoomCatalogRepository _repository;
  GetRoomCatalogUseCase(this._repository);

  @override
  Future<DataState<RoomCatalogEntity>> call(void params) =>
      _repository.getCatalog();
}
