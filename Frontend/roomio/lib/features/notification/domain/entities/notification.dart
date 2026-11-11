import 'package:equatable/equatable.dart';

class NotificationResponse extends Equatable {
  final String notificationId;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  const NotificationResponse({
    required this.notificationId,
    required this.content,
    required this.isRead,
    required this.createdAt,
  });

  NotificationResponse copyWith({bool? isRead}) => NotificationResponse(
    notificationId: notificationId,
    content: content,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
  );

  @override
  List<Object?> get props => [notificationId, content, isRead, createdAt];
}
