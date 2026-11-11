import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:roomio/core/constants/constants.dart';
import 'package:roomio/features/appointment/data/models/appointment.dart';

part 'appointment_api_service.g.dart';

@RestApi(baseUrl: appointmentAPIBaseUrl)
abstract class AppointmentApiService {
  factory AppointmentApiService(Dio dio, {String baseUrl}) =
      _AppointmentApiService;
  @POST('/')
  Future<HttpResponse<AppointmentModelResponse>> sendAppointment(
    @Body() AppointmentModelRequest request,
  );

  @GET('/')
  Future<HttpResponse<ListAppointmentResponseModel>> getAllAppointment();

  @PATCH('/{appointment_id}/{status}')
  Future<HttpResponse<AppointmentMessageModel>> confirmAppointment(
    @Path('appointment_id') String appointmentId,
    @Path('status') String status,
  );

  @DELETE('/{appointment_id}')
  Future<HttpResponse<AppointmentMessageModel>> destroyAppointment(
    @Path('appointment_id') String appointmentId,
  );

  @PATCH('/{appointment_id}')
  Future<HttpResponse<AppointmentMessageModel>> updateAppointment(
    @Path('appointment_id') String appointmentId,
    @Body() AppointmentModelRequest request,
  );
}
