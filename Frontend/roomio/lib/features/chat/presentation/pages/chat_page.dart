import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/features/chat/domain/entities/chat.dart';
import 'package:roomio/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:roomio/features/chat/presentation/bloc/chat_event.dart';
import 'package:roomio/features/chat/presentation/bloc/chat_state.dart';

class ChatPage extends StatefulWidget {
  final ConversationResponse conversation;
  final ChatSession session;
  const ChatPage({
    super.key,
    required this.conversation,
    required this.session,
  });
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  void _load() => context.read<ChatBloc>().add(
    ChatStarted(widget.conversation.targetUserId),
  );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  @override
  void didChangeMetrics() => _scrollToLatest();

  void _scrollToLatest() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _scrollController.hasClients) {
      // The reversed list keeps the newest bubble at offset zero.
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  });

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.conversation.targetUserName),
      actions: [
        IconButton(
          tooltip: 'Làm mới hội thoại',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: BlocConsumer<ChatBloc, ChatState>(
        listener: (context, state) {
          if (state.sentRevision > _lastSentRevision) {
            _lastSentRevision = state.sentRevision;
            _messageController.clear();
          }
          _scrollToLatest();
        },
        listenWhen: (previous, current) =>
            previous.messages != current.messages ||
            previous.sentRevision != current.sentRevision,
        builder: (context, state) => Column(
          children: [
            if (state.failure != null &&
                !state.realtimeUnavailable &&
                state.status != ChatStatus.failure)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  state.failure!.message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (state.realtimeUnavailable)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Tin nhắn realtime đang mất kết nối.'),
                    ),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Kết nối lại'),
                    ),
                  ],
                ),
              ),
            if (state.status == ChatStatus.loading)
              const LinearProgressIndicator(),
            Expanded(child: _messages(state)),
            if (state.messages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        enabled:
                            !state.sending && state.status == ChatStatus.loaded,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 500,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Nhập tin nhắn...',
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Gửi tin nhắn',
                      onPressed:
                          state.sending || state.status != ChatStatus.loaded
                          ? null
                          : () => context.read<ChatBloc>().add(
                              MessageSent(_messageController.text),
                            ),
                      icon: state.sending
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );

  int _lastSentRevision = 0;

  Widget _messages(ChatState state) {
    if (state.messages.isEmpty) {
      if (state.status == ChatStatus.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.status == ChatStatus.failure
                    ? 'Không tải được tin nhắn.'
                    : 'Chưa có tin nhắn. Khách thuê có thể liên hệ từ chi tiết phòng.',
                textAlign: TextAlign.center,
              ),
              if (state.status == ChatStatus.failure)
                TextButton(onPressed: _load, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      key: const Key('chat_messages'),
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: state.messages.length,
      itemBuilder: (context, index) {
        final message = state.messages[state.messages.length - index - 1];
        final mine = message.senderId == widget.session.accountId;
        final colors = Theme.of(context).colorScheme;
        final time = TimeOfDay.fromDateTime(
          message.updatedAt.toLocal(),
        ).format(context);
        return Align(
          key: ValueKey(message.messageId),
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * .78,
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: mine
                    ? colors.primaryContainer
                    : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(message.content),
                  const SizedBox(height: 4),
                  Text(time, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
