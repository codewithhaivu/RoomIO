import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/features/notification/domain/entities/notification.dart';
import 'package:roomio/features/notification/presentation/bloc/notification_bloc.dart';
import 'package:roomio/features/notification/presentation/bloc/notification_event.dart';
import 'package:roomio/features/notification/presentation/bloc/notification_state.dart';
import 'package:roomio/features/room/presentation/widgets/room_ui.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with WidgetsBindingObserver {
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    _load();
  }

  void _load() =>
      context.read<NotificationBloc>().add(const NotificationsStarted());

  void _onScroll() {
    if (!_scroll.hasClients || _scroll.position.extentAfter > 240) return;
    final bloc = context.read<NotificationBloc>();
    if (!bloc.state.loadMoreFailed) bloc.add(const NotificationsLoadMore());
  }

  Future<void> _refresh() async {
    final bloc = context.read<NotificationBloc>();
    if (bloc.state.refreshing) return;
    final completed = bloc.stream.firstWhere(
      (state) => !state.refreshing,
      orElse: () => bloc.state,
    );
    _load();
    await completed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _open(NotificationResponse notification) async {
    context.read<NotificationBloc>().add(
      NotificationReadRequested(notification.notificationId),
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .75,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Thông báo', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(_date(notification.createdAt)),
              const SizedBox(height: 16),
              SelectableText(notification.content),
            ],
          ),
        ),
      ),
    );
  }

  String _date(DateTime date) {
    final local = date.toLocal();
    String pad(int value) => value.toString().padLeft(2, '0');
    return '${pad(local.day)}/${pad(local.month)}/${local.year} · ${pad(local.hour)}:${pad(local.minute)}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Thông báo'),
      actions: [
        BlocBuilder<NotificationBloc, NotificationState>(
          builder: (context, state) => IconButton(
            tooltip: 'Làm mới thông báo',
            onPressed: state.refreshing ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ),
      ],
    ),
    body: SafeArea(
      child: BlocBuilder<NotificationBloc, NotificationState>(
        builder: (context, state) {
          if (state.notifications.isEmpty && state.refreshing) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              if (state.refreshing) const LinearProgressIndicator(),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    roomError(state.error!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: state.notifications.isEmpty
                        ? 1
                        : state.notifications.length + 1,
                    itemBuilder: (context, index) {
                      if (state.notifications.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 80),
                          child: Column(
                            children: [
                              const Icon(Icons.notifications_none, size: 56),
                              const SizedBox(height: 16),
                              Text(
                                state.status == NotificationStatus.failure
                                    ? 'Không tải được thông báo.'
                                    : 'Bạn chưa có thông báo nào.',
                                textAlign: TextAlign.center,
                              ),
                              if (state.status == NotificationStatus.failure)
                                TextButton(
                                  onPressed: _load,
                                  child: const Text('Thử lại'),
                                ),
                            ],
                          ),
                        );
                      }
                      if (index == state.notifications.length) {
                        if (state.loadingMore) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (!state.hasMore) return const SizedBox(height: 16);
                        return Center(
                          child: TextButton(
                            onPressed: state.refreshing
                                ? null
                                : () => context.read<NotificationBloc>().add(
                                    const NotificationsLoadMore(),
                                  ),
                            child: Text(
                              state.loadMoreFailed ? 'Thử tải lại' : 'Tải thêm',
                            ),
                          ),
                        );
                      }
                      final item = state.notifications[index];
                      final marking = state.markingIds.contains(
                        item.notificationId,
                      );
                      final colors = Theme.of(context).colorScheme;
                      return Card(
                        key: ValueKey(item.notificationId),
                        color: item.isRead ? null : colors.primaryContainer,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Icon(
                            item.isRead
                                ? Icons.notifications_outlined
                                : Icons.notifications_active,
                            color: item.isRead
                                ? colors.onSurfaceVariant
                                : colors.primary,
                          ),
                          title: Text(
                            item.content,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: item.isRead
                                  ? FontWeight.normal
                                  : FontWeight.w600,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${_date(item.createdAt)} · ${item.isRead ? 'Đã đọc' : 'Chưa đọc'}',
                            ),
                          ),
                          trailing: marking
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : item.isRead
                              ? null
                              : const Icon(Icons.circle, size: 10),
                          onTap: () => _open(item),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
