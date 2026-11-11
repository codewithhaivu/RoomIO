import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:roomio/core/storage/secure_storage_service.dart';
import 'package:roomio/features/chat/domain/entities/chat.dart';
import 'package:roomio/injection_container.dart';

Future<ChatSession?> loadChatSession() async {
  final storage = sl<SecureStorageService>();
  final values = await Future.wait([
    storage.getAccessToken(),
    storage.getRole(),
  ]);
  final token = values[0];
  final role = values[1];
  if (token == null ||
      (role != 'CUSTOMER' && role != 'TENANT' && role != 'LANDLORD')) {
    return null;
  }
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    // Identity for UI only; the server validates the JWT.
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    final id = payload['sub'];
    if (id is! String || id.trim().isEmpty) return null;
    return ChatSession(accountId: id, role: role!);
  } catch (_) {
    return null;
  }
}

/// Uses the signed-in session, never a role or sender ID supplied by a route.
class ChatSessionGate extends StatefulWidget {
  final Widget Function(BuildContext, ChatSession) builder;
  const ChatSessionGate({super.key, required this.builder});
  @override
  State<ChatSessionGate> createState() => _ChatSessionGateState();
}

class _ChatSessionGateState extends State<ChatSessionGate> {
  late Future<ChatSession?> _session;
  @override
  void initState() {
    super.initState();
    _session = loadChatSession();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ChatSession?>(
    future: _session,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError || snapshot.data == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Tin nhắn')),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Vui lòng đăng nhập lại để mở tin nhắn.'),
                TextButton(
                  onPressed: () => setState(() => _session = loadChatSession()),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        );
      }
      return widget.builder(context, snapshot.data!);
    },
  );
}
