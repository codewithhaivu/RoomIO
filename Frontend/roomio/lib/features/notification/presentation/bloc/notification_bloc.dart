import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/features/notification/domain/entities/notification.dart';
import 'package:roomio/features/notification/domain/usecases/get_notifications.dart';
import 'package:roomio/features/notification/domain/usecases/mark_notification_read.dart';
import 'notification_event.dart';
import 'notification_state.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final GetNotificationsUseCase _getNotifications;
  final MarkNotificationReadUseCase _markRead;
  final _readIds = <String>{};
  int _revision = 0;

  NotificationBloc(this._getNotifications, this._markRead)
    : super(const NotificationState()) {
    on<NotificationsStarted>(_refresh);
    on<NotificationsLoadMore>(_loadMore);
    on<NotificationReadRequested>(_read);
  }

  List<NotificationResponse> _merge(List<NotificationResponse> items) {
    final byId = <String, NotificationResponse>{};
    for (final item in items) {
      final read =
          item.isRead ||
          _readIds.contains(item.notificationId) ||
          byId[item.notificationId]?.isRead == true;
      byId[item.notificationId] = read ? item.copyWith(isRead: true) : item;
    }
    return byId.values.toList()..sort((a, b) {
      final time = b.createdAt.compareTo(a.createdAt);
      return time == 0 ? b.notificationId.compareTo(a.notificationId) : time;
    });
  }

  Future<void> _refresh(
    NotificationsStarted event,
    Emitter<NotificationState> emit,
  ) async {
    final revision = ++_revision;
    emit(
      state.copyWith(
        status: NotificationStatus.loading,
        loadingMore: false,
        loadMoreFailed: false,
        clearError: true,
      ),
    );
    final result = await _getNotifications(1);
    if (emit.isDone || revision != _revision) return;
    if (result.data != null) {
      emit(
        state.copyWith(
          status: NotificationStatus.loaded,
          notifications: _merge(result.data!),
          page: 1,
          hasMore: result.data!.length == 10,
        ),
      );
    } else {
      emit(
        state.copyWith(status: NotificationStatus.failure, error: result.error),
      );
    }
  }

  Future<void> _loadMore(
    NotificationsLoadMore event,
    Emitter<NotificationState> emit,
  ) async {
    if (state.refreshing ||
        state.loadingMore ||
        !state.hasMore ||
        state.page == 0) {
      return;
    }
    final revision = _revision;
    final page = state.page + 1;
    emit(
      state.copyWith(
        loadingMore: true,
        loadMoreFailed: false,
        clearError: true,
      ),
    );
    final result = await _getNotifications(page);
    if (emit.isDone || revision != _revision) return;
    if (result.data != null) {
      emit(
        state.copyWith(
          notifications: _merge([...state.notifications, ...result.data!]),
          page: page,
          hasMore: result.data!.length == 10,
          loadingMore: false,
        ),
      );
    } else {
      emit(
        state.copyWith(
          loadingMore: false,
          loadMoreFailed: true,
          error: result.error,
        ),
      );
    }
  }

  Future<void> _read(
    NotificationReadRequested event,
    Emitter<NotificationState> emit,
  ) async {
    final id = event.notificationId;
    final matches = state.notifications.where(
      (item) => item.notificationId == id,
    );
    if (matches.isEmpty ||
        matches.first.isRead ||
        state.markingIds.contains(id)) {
      return;
    }
    emit(
      state.copyWith(markingIds: {...state.markingIds, id}, clearError: true),
    );
    final result = await _markRead(id);
    if (emit.isDone) return;
    final marking = {...state.markingIds}..remove(id);
    if (result.data != null) {
      _readIds.add(id);
      emit(
        state.copyWith(
          notifications: _merge(state.notifications),
          markingIds: marking,
        ),
      );
    } else {
      emit(state.copyWith(markingIds: marking, error: result.error));
    }
  }

  @override
  Future<void> close() {
    _revision++;
    return super.close();
  }
}
