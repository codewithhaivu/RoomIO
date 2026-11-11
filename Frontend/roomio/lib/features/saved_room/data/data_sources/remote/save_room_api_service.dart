import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:roomio/core/constants/constants.dart';
import 'package:roomio/features/saved_room/data/models/save_room.dart';

part 'save_room_api_service.g.dart';

@RestApi(baseUrl: savedRoomAPIBaseUrl)
abstract class SavedRoomApiService {
  factory SavedRoomApiService(Dio dio, {String baseUrl}) = _SavedRoomApiService;

  @GET('/')
  Future<HttpResponse<ListSavedRoomResponseModel>> getSavedRoomInARoom();

  @DELETE('/{room_id}')
  Future<HttpResponse<MessageResponseModel>> deleteSavedRoomInARoom(
    @Path('room_id') String roomId,
  );

  @POST('/{room_id}')
  Future<HttpResponse<MessageResponseModel>> postSavedRoomInARoom(
    @Path('room_id') String roomId,
  );
}
