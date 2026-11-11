import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:roomio/core/constants/constants.dart';
import 'package:roomio/features/notification/data/models/notification.dart';

part 'device_api_service.g.dart';

@RestApi(baseUrl: deviceAPIBaseUrl)
abstract class DeviceApiService {
  factory DeviceApiService(Dio dio, {String baseUrl}) = _DeviceApiService;
  // quản lý thiết bị nhận thông báo
  @POST('/')
  Future<HttpResponse<RegisterDeviceResponse>> registerDevice(
    @Body() RegisterDeviceRequest request,
  );

  @PATCH('/{id_devices}')
  Future<HttpResponse<NotificationMessageModel>> updateDevice(
    @Path('id_devices') String idDevice,
    @Body() UpdateDeviceRequest request,
  );

  @DELETE('/{id_devices}')
  Future<HttpResponse<NotificationMessageModel>> unregisterDevice(
    @Path('id_devices') String idDevice,
  );
}
