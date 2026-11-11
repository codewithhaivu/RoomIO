import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/config/route/app_route.dart';
import 'package:roomio/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:roomio/features/chat/presentation/bloc/chat_event.dart';
import 'package:roomio/features/chat/presentation/bloc/chat_state.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});
  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  void _load() => context.read<ChatBloc>().add(const ChatListStarted());
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Tin nhắn'),
      actions: [
        IconButton(
          tooltip: 'Làm mới hội thoại',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        final conversations = state.conversations
            .where((c) => c.lastMessage.trim().isNotEmpty)
            .toList();
        return Column(
          children: [
            if (state.status == ChatStatus.loading)
              const LinearProgressIndicator(),
            if (state.realtimeUnavailable)
              ListTile(
                title: const Text('Tin nhắn realtime đang mất kết nối.'),
                trailing: TextButton(
                  onPressed: () {
                    // Restarting the subscription also retries the shared connection.
                    context.read<ChatBloc>().add(const ChatListStarted());
                  },
                  child: const Text('Kết nối lại'),
                ),
              ),
            Expanded(
              child: conversations.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.forum_outlined, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              state.status == ChatStatus.failure
                                  ? state.failure!.message
                                  : 'Chưa có hội thoại nào có tin nhắn.',
                              textAlign: TextAlign.center,
                            ),
                            if (state.status == ChatStatus.failure)
                              TextButton(
                                onPressed: _load,
                                child: const Text('Thử lại'),
                              ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: conversations.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final conversation = conversations[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              conversation.targetUserName.trim().isEmpty
                                  ? '?'
                                  : String.fromCharCode(
                                      conversation.targetUserName.runes.first,
                                    ),
                            ),
                          ),
                          title: Text(
                            conversation.targetUserName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            conversation.lastMessage,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.pushNamed(
                              context,
                              AppRoutes.chat,
                              arguments: conversation,
                            );
                            if (mounted) _load();
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    ),
  );
}
