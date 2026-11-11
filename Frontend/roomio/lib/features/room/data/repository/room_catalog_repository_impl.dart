import 'dart:io';
import 'package:dio/dio.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/room/data/data_sources/remote/room_catalog_api_service.dart';
import 'package:roomio/features/room/domain/entities/room_catalog_entity.dart';
import 'package:roomio/features/room/domain/repository/room_catalog_repository.dart';

class RoomCatalogRepositoryImpl implements RoomCatalogRepository {
  final RoomCatalogApiService _roomCatalogApiService;

  RoomCatalogRepositoryImpl(this._roomCatalogApiService);

  @override
  Future<DataState<RoomCatalogEntity>> getCatalog() async {
    try {
      final interiors = await _roomCatalogApiService.getInteriors();
      final amenities = await _roomCatalogApiService.getAmenities();
      final response = interiors.response.statusCode != HttpStatus.ok
          ? interiors.response
          : amenities.response;
      if (response.statusCode == HttpStatus.ok) {
        return DataSuccess(
          RoomCatalogEntity(
            interiors: interiors.data,
            amenities: amenities.data,
          ),
        );
      } else {
        return DataError(
          DioException(
            error: response.statusMessage,
            response: response,
            type: DioExceptionType.badResponse,
            requestOptions: response.requestOptions,
          ),
        );
      }
    } on DioException catch (e) {
      return DataError(e);
    }
  }
}
