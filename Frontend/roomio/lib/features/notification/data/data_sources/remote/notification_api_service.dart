import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:roomio/core/constants/constants.dart';
import 'package:roomio/features/notification/data/models/notification.dart';

part 'notification_api_service.g.dart';

@RestApi(baseUrl: notificationAPIBaseUrl)
abstract class NotificationlApiService {
  factory NotificationlApiService(Dio dio, {String baseUrl}) =
      _NotificationlApiService;

  // quản lý thông báo
  @GET('/')
  Future<HttpResponse<ListNotifcationModelResposne>> getNotifications(
    @Query('page') int page,
  );

  @PATCH('/{notification_id}/read')
  Future<HttpResponse<NotificationMessageModel>> markNotification(
    @Path('notification_id') String notifcationId,
  );
}
