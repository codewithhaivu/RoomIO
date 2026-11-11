import 'package:equatable/equatable.dart';

abstract class NotificationEvent extends Equatable {
  const NotificationEvent();
  @override
  List<Object?> get props => [];
}

class NotificationsStarted extends NotificationEvent {
  const NotificationsStarted();
}

class NotificationsLoadMore extends NotificationEvent {
  const NotificationsLoadMore();
}

class NotificationReadRequested extends NotificationEvent {
  final String notificationId;
  const NotificationReadRequested(this.notificationId);
  @override
  List<Object?> get props => [notificationId];
}
