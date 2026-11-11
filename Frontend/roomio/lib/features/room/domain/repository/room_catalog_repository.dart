import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/room/domain/entities/room_catalog_entity.dart';

abstract class RoomCatalogRepository {
  Future<DataState<RoomCatalogEntity>> getCatalog();
}
