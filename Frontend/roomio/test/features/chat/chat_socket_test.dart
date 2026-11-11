import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomio/core/error/failure.dart';
import 'package:roomio/features/chat/data/data_sources/remote/chat_api_service.dart';
import 'package:roomio/features/chat/data/data_sources/remote/chat_websocket_service.dart';
import 'package:roomio/features/chat/data/repository/chat_repository_impl.dart';
import 'package:roomio/features/chat/domain/entities/chat.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'chat_test_support.dart';

class _Channel implements WebSocketChannel {
  final input = StreamController<dynamic>();
  final output = _Sink();
  final Completer<void> handshake;
  _Channel({bool ready = true}) : handshake = Completer<void>() {
    if (ready) handshake.complete();
  }
  @override
  Stream<dynamic> get stream => input.stream;
  @override
  WebSocketSink get sink => output;
  @override
  Future<void> get ready => handshake.future;
  @override
  String? get protocol => null;
  @override
  int? get closeCode => null;
  @override
  String? get closeReason => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sink implements WebSocketSink {
  int sent = 0;
  int closed = 0;
  final _done = Completer<void>();
  @override
  void add(dynamic event) => sent++;
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future<void> addStream(Stream<dynamic> stream) async {
    await for (final event in stream) {
      add(event);
    }
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    closed++;
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> get done => _done.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => FlutterSecureStorage.setMockInitialValues({'access_token': 'token'}),
  );

  test(
    'inbox and chat share one authenticated receive-only connection',
    () async {
      final channels = <_Channel>[];
      final service = ChatWebSocketService(
        const FlutterSecureStorage(),
        openChannel: (url, token) {
          expect(url.path, '/ws/user/notifications');
          expect(token, 'token');
          final channel = _Channel();
          channels.add(channel);
          return channel;
        },
      );
      final dio = Dio();
      final repository = ChatRepositoryImpl(ChatApiService(dio), service);
      final inbox = <Either<Failure, MessageEntity>>[];
      final chat = <Either<Failure, MessageEntity>>[];
      final one = repository.listenToMessages().listen(inbox.add);
      final two = repository.listenToMessages().listen(chat.add);
      await pumpEventQueue();
      expect(channels.length, 1);
      channels.single.input.add({
        'type': 'chat_message',
        'data': messageJson(),
      });
      await pumpEventQueue();
      expect(inbox.single.isRight(), true);
      expect(chat.single.isRight(), true);
      await two.cancel();
      await pumpEventQueue();
      expect(channels.single.output.closed, 0);
      await one.cancel();
      await pumpEventQueue();
      expect(channels.single.output.closed, 1);
      expect(channels.single.output.sent, 0);
      await channels.single.input.close();
      dio.close();
    },
  );

  test('cancelling during handshake cannot deliver to a closed bloc', () async {
    final channel = _Channel(ready: false);
    final service = ChatWebSocketService(
      const FlutterSecureStorage(),
      openChannel: (_, _) => channel,
    );
    final subscription = service.messages.listen((_) {});
    final connecting = service.connect();
    await pumpEventQueue();
    await subscription.cancel();
    channel.handshake.complete();
    await connecting;
    await pumpEventQueue();
    expect(channel.output.closed, 1);
    expect(channel.input.hasListener, false);
    await channel.input.close();
  });

  test('a failed handshake can be retried', () async {
    final bad = _Channel(ready: false);
    final good = _Channel();
    var attempts = 0;
    final service = ChatWebSocketService(
      const FlutterSecureStorage(),
      openChannel: (_, _) => attempts++ == 0 ? bad : good,
    );
    final subscription = service.messages.listen((_) {});
    final failed = expectLater(service.connect(), throwsStateError);
    await pumpEventQueue();
    bad.handshake.completeError(StateError('offline'));
    await failed;
    await service.connect();
    expect(attempts, 2);
    await subscription.cancel();
    await pumpEventQueue();
    expect(good.output.closed, 1);
    await bad.input.close();
    await good.input.close();
  });
}
