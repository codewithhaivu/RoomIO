import 'dart:io';
import 'package:dio/dio.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/room/data/data_sources/remote/room_api_service.dart';
import 'package:roomio/features/room/data/models/room_detail_models.dart';
import 'package:roomio/features/room/data/models/nearby_room_models.dart';
import 'package:roomio/features/room/data/models/room_models.dart';
import 'package:roomio/features/room/data/models/room_sub_models.dart';
import 'package:roomio/features/room/domain/entities/room_place_suggestion.dart';
import 'package:roomio/features/room/domain/entities/room_sub_entities.dart';
import 'package:roomio/features/room/domain/repository/room_repository.dart';

class RoomRepositoryImpl implements RoomRepository {
  final RoomApiService _roomApiService;

  RoomRepositoryImpl(this._roomApiService);

  @override
  Future<DataState<RoomModel>> postRoom(
    String name,
    double area,
    double waterFee,
    double serviceFee,
    double parkingFee,
    double rentalPrice,
    double electricityFee,
    String status,
    String roomType,
    LocationEntity location,
    List<String> interiors,
    List<String> amenities,
    List<RoomImageEntity> images,
  ) async {
    try {
      final httpResponse = await _roomApiService.postRoom(
        PostRoomRequestModel(
          name: name,
          area: area,
          waterFee: waterFee,
          serviceFee: serviceFee,
          parkingFee: parkingFee,
          rentalPrice: rentalPrice,
          electricityFee: electricityFee,
          status: status,
          roomType: roomType,
          location: LocationModel.fromEntity(location),
          interiors: interiors,
          amenities: amenities,
          images: images
              .map((image) => RoomImageModel.fromEntity(image))
              .toList(),
        ),
      );

      if (httpResponse.response.statusCode == HttpStatus.ok ||
          httpResponse.response.statusCode == HttpStatus.created) {
        return DataSuccess(httpResponse.data);
      } else {
        return DataError(
          DioException(
            error: httpResponse.response.statusMessage,
            response: httpResponse.response,
            type: DioExceptionType.badResponse,
            requestOptions: httpResponse.response.requestOptions,
          ),
        );
      }
    } on DioException catch (e) {
      return DataError(e);
    }
  }

  @override
  Future<DataState<List<RoomImageModel>>> uploadImages(
    List<File> images,
    List<bool> isThumbnails,
  ) async {
    try {
      final httpResponse = await _roomApiService.uploadImages(
        images,
        isThumbnails,
      );

      if (httpResponse.response.statusCode == HttpStatus.ok ||
          httpResponse.response.statusCode == HttpStatus.created) {
        return DataSuccess(httpResponse.data.response);
      } else {
        return DataError(
          DioException(
            error: httpResponse.response.statusMessage,
            response: httpResponse.response,
            type: DioExceptionType.badResponse,
            requestOptions: httpResponse.response.requestOptions,
          ),
        );
      }
    } on DioException catch (e) {
      return DataError(e);
    }
  }

  @override
  Future<DataState<List<RoomModel>>> getListRoom() async {
    try {
      final httpResponse = await _roomApiService.getListRoom();

      if (httpResponse.response.statusCode == HttpStatus.ok) {
        return DataSuccess(httpResponse.data.rooms);
      } else {
        return DataError(
          DioException(
            error: httpResponse.response.statusMessage,
            response: httpResponse.response,
            type: DioExceptionType.badResponse,
            requestOptions: httpResponse.response.requestOptions,
          ),
        );
      }
    } on DioException catch (e) {
      return DataError(e);
    }
  }

  @override
  Future<DataState<RoomDetailModel>> getDetailRoom(String roomId) async {
    try {
      final httpResponse = await _roomApiService.getDetailRoom(roomId);

      if (httpResponse.response.statusCode == HttpStatus.ok) {
        return DataSuccess(httpResponse.data);
      } else {
        return DataError(
          DioException(
            error: httpResponse.response.statusMessage,
            response: httpResponse.response,
            type: DioExceptionType.badResponse,
            requestOptions: httpResponse.response.requestOptions,
          ),
        );
      }
    } on DioException catch (e) {
      return DataError(e);
    }
  }

  @override
  Future<DataState<RoomDetailModel>> updateRoom(
    String roomId, {
    String? name,
    double? area,
    double? waterFee,
    double? serviceFee,
    double? parkingFee,
    double? rentalPrice,
    double? electricityFee,
    String? status,
    String? roomType,
    LocationEntity? location,
    List<String>? interiors,
    List<String>? amenities,
    List<RoomImageEntity>? images,
  }) async {
    try {
      final httpResponse = await _roomApiService.updateRoom(
        roomId,
        UpdateRoomRequestModel(
          name: name,
          area: area,
          waterFee: waterFee,
          serviceFee: serviceFee,
          parkingFee: parkingFee,
          rentalPrice: rentalPrice,
          electricityFee: electricityFee,
          status: status,
          roomType: roomType,
          location: location == null
              ? null
              : LocationModel.fromEntity(location),
          interiors: interiors,
          amenities: amenities,
          images: images
              ?.map((image) => RoomImageModel.fromEntity(image))
              .toList(),
        ),
      );

      if (httpResponse.response.statusCode == HttpStatus.ok) {
        return DataSuccess(httpResponse.data);
      } else {
        return DataError(
          DioException(
            error: httpResponse.response.statusMessage,
            response: httpResponse.response,
            type: DioExceptionType.badResponse,
            requestOptions: httpResponse.response.requestOptions,
          ),
        );
      }
    } on DioException catch (e) {
      return DataError(e);
    }
  }

  @override
  Future<DataState<String>> updateStatusRoom(
    String roomId,
    String status,
  ) async {
    try {
      final httpResponse = await _roomApiService.updateStatusRoom(
        roomId,
        status,
      );

      if (httpResponse.response.statusCode == HttpStatus.ok) {
        final data = httpResponse.data;
        if (data is Map && data['Message'] is String) {
          return DataSuccess<String>(data['Message'] as String);
        }
      }
      return DataError(
        DioException(
          error: httpResponse.response.statusMessage,
          response: httpResponse.response,
          type: DioExceptionType.badResponse,
          requestOptions: httpResponse.response.requestOptions,
        ),
      );
    } on DioException catch (e) {
      return DataError(e);
    }
  }

  @override
  Future<DataState<List<NearbyRoomModel>>> searchRoomByPosition(
    double latitude,
    double longitude,
    double radius,
  ) async {
    try {
      final httpResponse = await _roomApiService.searchRoomByPosition(
        latitude,
        longitude,
        radius,
      );

      if (httpResponse.response.statusCode == HttpStatus.ok) {
        return DataSuccess(httpResponse.data.rooms);
      } else {
        return DataError(
          DioException(
            error: httpResponse.response.statusMessage,
            response: httpResponse.response,
            type: DioExceptionType.badResponse,
            requestOptions: httpResponse.response.requestOptions,
          ),
        );
      }
    } on DioException catch (e) {
      return DataError(e);
    }
  }

  @override
  Future<DataState<List<NearbyRoomModel>>> searchRoomsByArea(
    String locationId,
    String district, {
    double radius = 10,
  }) async {
    try {
      final httpResponse = await _roomApiService.searchRoomsByArea(
        locationId,
        district,
        radius: radius,
      );

      if (httpResponse.response.statusCode == HttpStatus.ok) {
        return DataSuccess(httpResponse.data.rooms);
      } else {
        return DataError(
          DioException(
            error: httpResponse.response.statusMessage,
            response: httpResponse.response,
            type: DioExceptionType.badResponse,
            requestOptions: httpResponse.response.requestOptions,
          ),
        );
      }
    } on DioException catch (e) {
      return DataError(e);
    }
  }

  @override
  Future<DataState<List<LocationSuggestion>>> getLocationSuggestion() async {
    try {
      final httpResponse = await _roomApiService.getLocationSuggestion();
      if (httpResponse.response.statusCode == HttpStatus.ok) {
        return DataSuccess(httpResponse.data.data);
      }
      return DataError(
        DioException(
          error: httpResponse.response.statusMessage,
          response: httpResponse.response,
          type: DioExceptionType.badResponse,
          requestOptions: httpResponse.response.requestOptions,
        ),
      );
    } on DioException catch (e) {
      return DataError(e);
    } catch (error, stackTrace) {
      return DataError(
        DioException(
          error: error,
          stackTrace: stackTrace,
          requestOptions: RequestOptions(path: '/locations'),
        ),
      );
    }
  }
}
