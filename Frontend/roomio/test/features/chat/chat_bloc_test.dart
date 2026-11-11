import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomio/core/error/failure.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/chat/domain/entities/chat.dart';
import 'package:roomio/features/chat/domain/usecases/contact_landlord_usecase.dart';
import 'package:roomio/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:roomio/features/chat/presentation/bloc/chat_event.dart';
import 'package:roomio/features/chat/presentation/bloc/chat_state.dart';
import 'chat_test_support.dart';

void main() {
  late FakeChatRepository repository;
  late ChatBloc bloc;
  setUp(() {
    repository = FakeChatRepository();
    bloc = chatBloc(repository);
  });
  tearDown(() async {
    await bloc.close();
    await repository.events.close();
  });

  Future<void> start() async {
    bloc.add(const ChatStarted('landlord-id'));
    await pumpEventQueue();
    expect(bloc.state.status, ChatStatus.loaded);
  }

  test(
    'merges realtime arriving during history load and deduplicates',
    () async {
      final pending = Completer<DataState<List<MessageResponse>>>();
      repository.historyLoads.add(pending);
      bloc.add(const ChatStarted('landlord-id'));
      await pumpEventQueue();
      repository.events.add(
        Right(
          message(
            id: 'live',
            sender: 'landlord-id',
            receiver: 'tenant-id',
            minute: 1,
          ),
        ),
      );
      repository.events.add(
        Right(message(id: 'other', sender: 'someone', receiver: 'tenant-id')),
      );
      await pumpEventQueue();
      pending.complete(DataSuccess([message()]));
      await pumpEventQueue();
      repository.events.add(
        Right(
          message(
            id: 'live',
            sender: 'landlord-id',
            receiver: 'tenant-id',
            minute: 1,
          ),
        ),
      );
      await pumpEventQueue();
      expect(bloc.state.messages.map((m) => m.messageId), [
        'message-1',
        'live',
      ]);
    },
  );

  test(
    'restarting listens once, ignores stale history and close cancels',
    () async {
      final old = Completer<DataState<List<MessageResponse>>>();
      repository.historyLoads.add(old);
      bloc.add(const ChatStarted('old-user'));
      await pumpEventQueue();
      bloc.add(const ChatStarted('landlord-id'));
      await pumpEventQueue();
      old.complete(DataSuccess([message(id: 'stale')]));
      await pumpEventQueue();
      expect(bloc.state.messages.single.messageId, 'message-1');
      expect(repository.listenCalls, 2);
      expect(repository.events.hasListener, true);
      await bloc.close();
      expect(repository.events.hasListener, false);
    },
  );

  test('rapid starts do not leave duplicate subscriptions', () async {
    bloc.add(const ChatStarted('landlord-id'));
    bloc.add(const ChatStarted('landlord-id'));
    await pumpEventQueue();
    await bloc.close();
    expect(repository.events.hasListener, false);
  });

  test('REST acknowledgement refreshes history without socket echo', () async {
    await start();
    bloc.add(const MessageSent('  Xin chào  '));
    await pumpEventQueue();
    expect(repository.sent.single.content, 'Xin chào');
    expect(repository.sent.single.type, 'chat_message');
    expect(bloc.state.messages.last.content, 'Xin chào');
    expect(bloc.state.sentRevision, 1);
    expect(bloc.state.sending, false);
  });

  test(
    'duplicate sends and reload while sending cannot submit twice',
    () async {
      await start();
      final pending = repository.pendingSend = Completer<DataState<bool>>();
      bloc.add(const MessageSent('Hi'));
      bloc.add(const MessageSent('Hi'));
      bloc.add(const ChatStarted('landlord-id'));
      await pumpEventQueue();
      expect(repository.sent.length, 1);
      pending.complete(const DataSuccess(true));
      await pumpEventQueue();
      expect(bloc.state.sending, false);
    },
  );

  test('send failure keeps history and does not acknowledge draft', () async {
    await start();
    repository.sendValid = false;
    bloc.add(const MessageSent('Hi'));
    await pumpEventQueue();
    expect(bloc.state.failure, isNotNull);
    expect(bloc.state.messages.length, 1);
    expect(bloc.state.sentRevision, 0);
  });

  test(
    'acknowledged send with failed refresh is never retried automatically',
    () async {
      await start();
      repository.historyError = DioException(
        requestOptions: RequestOptions(path: 'history'),
      );
      bloc.add(const MessageSent('Hi'));
      await pumpEventQueue();
      expect(repository.sent.length, 1);
      expect(bloc.state.sentRevision, 1);
      expect(bloc.state.failure!.message, contains('Đã gửi'));
      expect(bloc.state.messages.length, 1);
    },
  );

  test('empty chat cannot initiate from ChatPage for either role', () async {
    repository.history = [];
    await start();
    bloc.add(const MessageSent('Hi'));
    await pumpEventQueue();
    expect(repository.sent, isEmpty);
    final ownerBloc = chatBloc(repository, session: landlord);
    ownerBloc.add(const ChatStarted('tenant-id'));
    await pumpEventQueue();
    ownerBloc.add(const MessageSent('Hi'));
    await pumpEventQueue();
    expect(repository.sent, isEmpty);
    await ownerBloc.close();
  });

  test('rejects blank/overlong messages before calling REST', () async {
    await start();
    bloc.add(const MessageSent('   '));
    bloc.add(MessageSent('a' * 501));
    await pumpEventQueue();
    expect(repository.sent, isEmpty);
  });

  test(
    'inbox filters empty conversations and reloads on socket message',
    () async {
      repository.conversations = [
        conversation(),
        conversation(target: 'empty', text: ' '),
      ];
      bloc.add(const ChatListStarted());
      await pumpEventQueue();
      expect(bloc.state.conversations.length, 1);
      repository.events.add(Right(message()));
      await pumpEventQueue();
      expect(repository.listCalls, 2);
    },
  );

  test('inbox reconnect re-subscribes after connection failure', () async {
    bloc.add(const ChatListStarted());
    await pumpEventQueue();
    repository.events.add(const Left(Failure('offline', connectionLost: true)));
    await pumpEventQueue();
    expect(bloc.state.realtimeUnavailable, true);
    bloc.add(const ChatListStarted());
    await pumpEventQueue();
    expect(repository.listenCalls, 2);
  });

  test(
    'contact reuses history without sending an automatic greeting',
    () async {
      final result = await ContactLandlordUseCase(repository)(
        session: tenant,
        landlordAccountId: 'landlord-id',
      );
      expect(result, const Right<Failure, bool>(true));
      expect(repository.sent, isEmpty);
    },
  );

  test(
    'only tenant may create through explicit first-message content',
    () async {
      repository.history = [];
      final useCase = ContactLandlordUseCase(repository);
      expect(
        (await useCase(session: landlord, landlordAccountId: 'other')).isLeft(),
        true,
      );
      expect(
        (await useCase(
          session: tenant,
          landlordAccountId: 'tenant-id',
        )).isLeft(),
        true,
      );
      expect(
        await useCase(session: tenant, landlordAccountId: 'landlord-id'),
        const Right<Failure, bool>(false),
      );
      expect(repository.sent, isEmpty);
      expect(
        await useCase(
          session: tenant,
          landlordAccountId: 'landlord-id',
          firstMessage: '  Xin chào  ',
        ),
        const Right<Failure, bool>(true),
      );
      expect(repository.sent.single.content, 'Xin chào');
    },
  );

  test(
    'first-message draft is sent if a conversation appeared in the meantime',
    () async {
      await ContactLandlordUseCase(repository)(
        session: tenant,
        landlordAccountId: 'landlord-id',
        firstMessage: 'My draft',
      );
      expect(repository.sent.single.content, 'My draft');
    },
  );
}
