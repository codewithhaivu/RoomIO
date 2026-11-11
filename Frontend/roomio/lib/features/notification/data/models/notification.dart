import 'package:roomio/features/notification/domain/entities/notification.dart';

class NotifcationModelResposne extends NotificationResponse {
  const NotifcationModelResposne({
    required super.notificationId,
    required super.content,
    required super.isRead,
    required super.createdAt,
  });
  factory NotifcationModelResposne.fromJson(Map<String, dynamic> json) {
    final value = json['created_at'] as String;
    final parsed = DateTime.parse(value);
    // MySQL can omit the offset although the backend stores UTC.
    final timestamp = parsed.isUtc || RegExp(r'[+-]\d\d:\d\d$').hasMatch(value)
        ? parsed.toUtc()
        : DateTime.parse('${value}Z');
    return NotifcationModelResposne(
      notificationId: json['notification_id'] as String,
      content: json['content'] as String,
      isRead: json['is_read'] as bool,
      createdAt: timestamp,
    );
  }
}

class NotificationMessageModel {
  final String message;
  const NotificationMessageModel({required this.message});

  factory NotificationMessageModel.fromJson(Map<String, dynamic> json) =>
      NotificationMessageModel(message: json['message'] as String);
}

class ListNotifcationModelResposne {
  final List<NotifcationModelResposne> data;
  const ListNotifcationModelResposne({required this.data});
  factory ListNotifcationModelResposne.fromJson(Map<String, dynamic> json) =>
      ListNotifcationModelResposne(
        data: (json['data'] as List<dynamic>)
            .map(
              (item) => NotifcationModelResposne.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList(),
      );
}


class RegisterDeviceRequest {
  final String fcmToken;
  final String platform;
  const RegisterDeviceRequest({
    required this.fcmToken,
    required this.platform,
  });

  Map<String, dynamic> toJson() => {
        'fcm_token': fcmToken,
        'platform': platform,
      };
}

class RegisterDeviceResponse {
  final String idDevice;
  const RegisterDeviceResponse({required this.idDevice});

  factory RegisterDeviceResponse.fromJson(Map<String, dynamic> json) =>
      RegisterDeviceResponse(idDevice: json['id_device'] as String);
}


class UpdateDeviceRequest {
  final String fcmToken;
  const UpdateDeviceRequest({required this.fcmToken});

  Map<String, dynamic> toJson() => {
        'fcm_token': fcmToken,
      };
}