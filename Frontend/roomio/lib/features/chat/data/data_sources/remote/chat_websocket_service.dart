import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:roomio/core/constants/constants.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// One receive-only connection shared by the inbox and conversation page.
class ChatWebSocketService {
  final FlutterSecureStorage secureStorage;
  final Uri url;
  final WebSocketChannel Function(Uri, String) _openChannel;
  late final StreamController<dynamic> _events;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Future<void>? _connecting;
  int _generation = 0;

  ChatWebSocketService(
    this.secureStorage, {
    Uri? url,
    WebSocketChannel Function(Uri, String)? openChannel,
  }) : url =
           url ??
           Uri.parse(chatAPIBaseUrl).replace(
             scheme: Uri.parse(chatAPIBaseUrl).scheme == 'https' ? 'wss' : 'ws',
             path: '/ws/user/notifications',
           ),
       _openChannel = openChannel ?? _defaultChannel {
    _events = StreamController<dynamic>.broadcast(
      onCancel: () => unawaited(disconnect()),
    );
  }

  static WebSocketChannel _defaultChannel(Uri url, String token) =>
      IOWebSocketChannel.connect(
        url,
        headers: {'Authorization': 'Bearer $token'},
        connectTimeout: const Duration(seconds: 10),
      );

  Stream<dynamic> get messages => _events.stream;

  Future<void> connect() {
    if (_connecting != null) return _connecting!;
    if (_channel != null) return Future.value();
    final generation = _generation;
    final pending = _connect(generation);
    _connecting = pending;
    return pending.whenComplete(() {
      if (identical(_connecting, pending)) _connecting = null;
    });
  }

  Future<void> _connect(int generation) async {
    final token = await secureStorage.read(key: 'access_token');
    if (generation != _generation) return;
    if (token == null || token.isEmpty) {
      throw StateError('Không tìm thấy access token');
    }
    final channel = _channel = _openChannel(url, token);
    var ready = false;
    _subscription = channel.stream.listen(
      (event) {
        if (generation == _generation) _events.add(event);
      },
      onError: (Object error, StackTrace stack) {
        if (ready && generation == _generation) _events.addError(error, stack);
      },
      onDone: () {
        if (generation == _generation) {
          _channel = null;
          if (ready && _events.hasListener) {
            _events.addError(StateError('Kết nối tin nhắn đã đóng'));
          }
        }
      },
    );
    try {
      await channel.ready;
      ready = true;
    } catch (_) {
      if (generation == _generation) await disconnect();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    _generation++;
    final subscription = _subscription;
    final channel = _channel;
    _subscription = null;
    _channel = null;
    _connecting = null;
    await subscription?.cancel();
    await channel?.sink.close();
  }
}
