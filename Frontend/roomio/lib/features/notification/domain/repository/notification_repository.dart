import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/notification/domain/entities/notification.dart';

abstract class NotificationRepository {
  // quản lý thông báo
  Future<DataState<List<NotificationResponse>>> getNotifications(int page);
  Future<DataState<String>> markNotifications(String notificationId);

  // quản lý thiết bị nhận thông báo
  Future<DataState<String>> registerDevice(String fcmToken, String platform);
  Future<DataState<String>> updateDevice(String fcmToken, String idDevice);
  Future<DataState<String>> unregisterDevice(String idDevice);
}
