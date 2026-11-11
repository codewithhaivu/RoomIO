import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:roomio/features/notification/domain/entities/notification.dart';

enum NotificationStatus { initial, loading, loaded, failure }

class NotificationState extends Equatable {
  final NotificationStatus status;
  final List<NotificationResponse> notifications;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final bool loadMoreFailed;
  final Set<String> markingIds;
  final DioException? error;

  const NotificationState({
    this.status = NotificationStatus.initial,
    this.notifications = const [],
    this.page = 0,
    this.hasMore = true,
    this.loadingMore = false,
    this.loadMoreFailed = false,
    this.markingIds = const {},
    this.error,
  });

  bool get refreshing => status == NotificationStatus.loading;

  NotificationState copyWith({
    NotificationStatus? status,
    List<NotificationResponse>? notifications,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    bool? loadMoreFailed,
    Set<String>? markingIds,
    DioException? error,
    bool clearError = false,
  }) => NotificationState(
    status: status ?? this.status,
    notifications: notifications == null
        ? this.notifications
        : List.unmodifiable(notifications),
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    markingIds: markingIds == null
        ? this.markingIds
        : Set.unmodifiable(markingIds),
    error: error ?? (clearError ? null : this.error),
  );

  @override
  List<Object?> get props => [
    status,
    notifications,
    page,
    hasMore,
    loadingMore,
    loadMoreFailed,
    markingIds,
    error,
  ];
}
