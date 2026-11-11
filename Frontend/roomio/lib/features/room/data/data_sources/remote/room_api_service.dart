import 'dart:io';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:roomio/core/constants/constants.dart';
import 'package:roomio/features/room/data/models/room_detail_models.dart';
import 'package:roomio/features/room/data/models/room_models.dart';
import 'package:roomio/features/room/data/models/room_sub_models.dart';
// Import thêm file chứa PostRoomRequestModel và UpdateRoomRequestModel của bạn

part 'room_api_service.g.dart';

@RestApi(baseUrl: roomAPIBaseUrl)
abstract class RoomApiService {
  factory RoomApiService(Dio dio, {String baseUrl}) = _RoomApiService;

  @GET('/locations')
  Future<HttpResponse<ListLocationSuggestionModelResponse>> getLocationSuggestion();
  
  @POST('')
  Future<HttpResponse<RoomModel>> postRoom(
    @Body() PostRoomRequestModel request,
  );

  @POST('/images/upload')
  @MultiPart()
  Future<HttpResponse<ListImageResponseModel>> uploadImages(
    @Part(name: 'images') List<File> images,
    @Part(name: 'is_thumbnails') List<bool> isThumbnails,
  );

  @GET('/me')
  Future<HttpResponse<ListRoomResponseModel>> getListRoom();

  @GET('/{room_id}')
  Future<HttpResponse<RoomDetailModel>> getDetailRoom(
    @Path('room_id') String roomId,
  );

  @PATCH('/{room_id}')
  Future<HttpResponse<RoomDetailModel>> updateRoom(
    @Path('room_id') String roomId,
    @Body() UpdateRoomRequestModel request,
  );

  @PATCH('/{room_id}/{status}')
  Future<HttpResponse<dynamic>> updateStatusRoom(
    @Path('room_id') String roomId,
    @Path('status') String status,
  );

  @GET('/nearby/position')
  Future<HttpResponse<ListNearbyRoomResponseModel>> searchRoomByPosition(
    @Query('latitude') double latitude,
    @Query('longitude') double longitude,
    @Query('radius') double radius,
  );

  @GET('/nearby/district')
  Future<HttpResponse<ListNearbyRoomResponseModel>> searchRoomsByArea(
    @Query('location_id') String locationId,
    @Query('district') String district, {
    @Query('radius') double radius = 10,
  });


}
