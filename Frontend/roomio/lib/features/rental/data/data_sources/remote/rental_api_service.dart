import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:roomio/core/constants/constants.dart';
import 'package:roomio/features/rental/data/models/rental.dart';

part 'rental_api_service.g.dart';

@RestApi(baseUrl: rentalAPIBaseUrl)
abstract class RentalApiService {
  factory RentalApiService(Dio dio, {String baseUrl}) = _RentalApiService;
  @POST('/{room_id}/qr-code')
  Future<HttpResponse<RentalModelResponse>> createQRCode(
    @Path('room_id') String roomId,
  );

  @DELETE('/{rental_relation_id}')
  Future<HttpResponse<RentalMessageModel>> destroyRelation(
    @Path('rental_relation_id') String rentalRelationId,
  );

  @GET('/my-rooms')
  Future<HttpResponse<MyRentedRoomsResponseModel>> getCurrentRentRoom();

  @GET('/')
  Future<HttpResponse<CurrentTenantsResponseModel>> getMyTenants();

  @POST('/qr-code/verify')
  Future<HttpResponse<RentalModelVerifyResponse>> verifyQRCode(
    @Body() RentalModelVerifyRequest request,
  );
}
