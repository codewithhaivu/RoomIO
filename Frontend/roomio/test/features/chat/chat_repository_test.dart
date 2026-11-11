import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomio/core/error/failure.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/chat/domain/entities/chat.dart';
import 'chat_test_support.dart';

void main() {
  late ChatTestApi api;
  setUp(() => api = ChatTestApi());
  tearDown(() => api.dispose());

  test('POST sends the backend payload through REST only', () async {
    api.data = {'id_valid': true};
    api.statusCode = 201;
    final result = await api.repository.sendMessage(
      ChatMessageRequest(
        type: 'chat_message',
        receiverId: 'landlord-id',
        content: 'Xin chào',
        status: 'active',
        updatedAt: DateTime.utc(2030),
      ),
    );
    expect(result.data, true);
    expect(api.requests.single.method, 'POST');
    expect(api.requests.single.uri.path, '/chat/messages');
    expect(api.requests.single.data, {
      'type': 'chat_message',
      'receiver_id': 'landlord-id',
      'content': 'Xin chào',
      'status': 'active',
      'created_at': '2030-01-01T00:00:00.000Z',
    });
    expect(api.socket.connections, 0);
  });

  test('history decodes IDs and normalizes server timestamps', () async {
    api.data = {
      'data': [messageJson()..['created_at'] = '2030-01-01T09:00:00+07:00'],
    };
    final result = await api.repository.getMessages('landlord-id');
    expect(result.data!.single.updatedAt, DateTime.utc(2030, 1, 1, 2));
    expect(api.requests.single.uri.path, '/chat/messages/landlord-id');
  });

  test('inbox excludes empty conversations and sorts latest first', () async {
    Map<String, dynamic> row(String id, String text, String time) => {
      'target_user_id': id,
      'target_user_name': id,
      'last_message': text,
      'updated_at': time,
    };
    api.data = {
      'data': [
        row('old', 'Hello', '2030-01-01T00:00:00'),
        row('empty', '  ', '2030-01-03T00:00:00'),
        row('new', 'Reply', '2030-01-02T00:00:00'),
      ],
    };
    final result = await api.repository.getConversations();
    expect(result.data!.map((c) => c.targetUserId), ['new', 'old']);
    expect(result.data!.first.updatedAt.isUtc, true);
  });

  test('HTTP and malformed data failures become DataError', () async {
    api.data = {'id_valid': true};
    api.statusCode = 403;
    expect(
      await api.repository.sendMessage(
        ChatMessageRequest(
          type: 'chat_message',
          receiverId: 'x',
          content: 'Hello',
          status: 'active',
          updatedAt: DateTime.utc(2030),
        ),
      ),
      isA<DataError<bool>>(),
    );
    api.statusCode = 200;
    api.data = {
      'data': [
        {'message_id': 'bad'},
      ],
    };
    expect(
      await api.repository.getMessages('x'),
      isA<DataError<List<MessageResponse>>>(),
    );
    api.error = DioException(requestOptions: RequestOptions(path: '/messages'));
    expect(await api.repository.getConversations(), isA<DataError>());
  });

  test(
    'socket parses data envelope and continues after malformed events',
    () async {
      final results = <Either<Failure, MessageEntity>>[];
      final subscription = api.repository.listenToMessages().listen(
        results.add,
      );
      await pumpEventQueue();
      api.socket.events.add('not-json');
      api.socket.events.add(
        jsonEncode({'type': 'appointment_confirmed', 'data': {}}),
      );
      api.socket.events.add(
        jsonEncode({
          'type': 'chat_message',
          'data': {'message_id': 'invalid'},
        }),
      );
      api.socket.events.add(
        utf8.encode(
          jsonEncode({'type': 'chat_message', 'data': messageJson()}),
        ),
      );
      api.socket.events.add({
        'type': 'chat_message',
        'data': messageJson('message-2'),
      });
      await pumpEventQueue();
      expect(results.length, 4);
      expect(results.take(2).every((result) => result.isLeft()), true);
      expect(
        results[2].getOrElse(() => throw StateError('missing')).messageId,
        'message-1',
      );
      expect(
        results.last.getOrElse(() => throw StateError('missing')).messageId,
        'message-2',
      );
      await subscription.cancel();
    },
  );

  test('socket handshake errors are delivered as Left failures', () async {
    api.socket.connectError = StateError('offline');
    final result = await api.repository.listenToMessages().first;
    expect(result.isLeft(), true);
    expect(
      result.fold((failure) => failure.connectionLost, (_) => false),
      true,
    );
  });

  test('socket errors do not terminate later messages', () async {
    final results = <Either<Failure, MessageEntity>>[];
    final subscription = api.repository.listenToMessages().listen(results.add);
    await pumpEventQueue();
    api.socket.events.addError(StateError('offline'));
    api.socket.events.add({'type': 'chat_message', 'data': messageJson()});
    await pumpEventQueue();
    expect(results.first.isLeft(), true);
    expect(results.last.isRight(), true);
    await subscription.cancel();
  });
}
