import 'package:flutter/material.dart';
import 'package:roomio/config/route/app_route.dart';
import 'package:roomio/features/chat/domain/entities/chat.dart';
import 'package:roomio/features/chat/domain/usecases/contact_landlord_usecase.dart';
import 'package:roomio/features/chat/presentation/widgets/chat_session_gate.dart';
import 'package:roomio/injection_container.dart';

/// Embed in room details. The ID must be the landlord's ACCOUNT ID.
class ContactLandlordButton extends StatefulWidget {
  final String landlordAccountId;
  final String landlordName;
  final String? landlordAvatarUrl;
  const ContactLandlordButton({
    super.key,
    required this.landlordAccountId,
    required this.landlordName,
    this.landlordAvatarUrl,
  });
  @override
  State<ContactLandlordButton> createState() => _ContactLandlordButtonState();
}

class _ContactLandlordButtonState extends State<ContactLandlordButton> {
  late final Future<ChatSession?> _session;
  bool _opening = false;
  @override
  void initState() {
    super.initState();
    _session = loadChatSession();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ChatSession?>(
    future: _session,
    builder: (context, snapshot) {
      final session = snapshot.data;
      if (session == null ||
          !session.isTenant ||
          session.accountId == widget.landlordAccountId) {
        return const SizedBox.shrink();
      }
      return OutlinedButton.icon(
        onPressed: _opening ? null : () => _open(session),
        icon: const Icon(Icons.chat_bubble_outline),
        label: Text(_opening ? 'Đang mở...' : 'Liên hệ chủ trọ'),
      );
    },
  );

  Future<void> _open(ChatSession session) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final result = await sl<ContactLandlordUseCase>()(
        session: session,
        landlordAccountId: widget.landlordAccountId,
      );
      if (!mounted) return;
      final existing = result.fold<bool?>((failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
        return null;
      }, (ready) => ready);
      if (existing == null) return;
      final ready =
          existing ||
          await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) => _FirstMessageDialog(
                  session: session,
                  landlordAccountId: widget.landlordAccountId,
                  landlordName: widget.landlordName,
                ),
              ) ==
              true;
      if (!mounted || !ready) return;
      await Navigator.pushNamed(
        context,
        AppRoutes.chat,
        arguments: ConversationResponse(
          targetUserId: widget.landlordAccountId,
          targetUserName: widget.landlordName,
          targetAvatarUrl: widget.landlordAvatarUrl,
          lastMessage: '',
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }
}

/// First-message input stays in the room-detail contact flow.
class _FirstMessageDialog extends StatefulWidget {
  final ChatSession session;
  final String landlordAccountId;
  final String landlordName;
  const _FirstMessageDialog({
    required this.session,
    required this.landlordAccountId,
    required this.landlordName,
  });
  @override
  State<_FirstMessageDialog> createState() => _FirstMessageDialogState();
}

class _FirstMessageDialogState extends State<_FirstMessageDialog> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await sl<ContactLandlordUseCase>()(
      session: widget.session,
      landlordAccountId: widget.landlordAccountId,
      firstMessage: _controller.text,
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _busy = false;
        _error = failure.message;
      }),
      (ready) => Navigator.pop(context, ready),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text('Liên hệ ${widget.landlordName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Gửi lời nhắn đầu tiên cho chủ trọ'),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              enabled: !_busy,
              autofocus: true,
              maxLength: 500,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Tôi muốn tìm hiểu thêm về phòng...',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _send,
          icon: const Icon(Icons.send),
          label: Text(_busy ? 'Đang gửi...' : 'Gửi và mở hội thoại'),
        ),
      ],
    ),
  );
}
