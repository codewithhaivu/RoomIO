import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/core/error/failure.dart';
import 'package:roomio/features/chat/domain/entities/chat.dart';
import 'package:roomio/features/chat/domain/usecases/get_conversations_usecase.dart';
import 'package:roomio/features/chat/domain/usecases/get_messages_usecase.dart';
import 'package:roomio/features/chat/domain/usecases/listen_to_messages_usecase.dart';
import 'package:roomio/features/chat/domain/usecases/send_message_usecase.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final GetMessagesUseCase _getMessages;
  final SendMessageUseCase _sendMessage;
  final ListenToMessagesUseCase _listenToMessages;
  final GetConversationsUseCase _getConversations;
  final ChatSession session;
  StreamSubscription<Either<Failure, MessageEntity>>? _subscription;
  String? _targetUserId;
  bool _listMode = false;
  int _operation = 0;
  bool _closing = false;

  ChatBloc(
    this._getMessages,
    this._sendMessage,
    this._listenToMessages,
    this._getConversations,
    this.session,
  ) : super(const ChatState()) {
    on<ChatStarted>(_start);
    on<ChatListStarted>(_loadConversations);
    on<MessageReceived>(_receive);
    on<MessageSent>(_send);
    on<ChatStreamFailed>(
      (event, emit) => emit(
        state.copyWith(
          failure: event.failure,
          realtimeUnavailable: event.failure.connectionLost
              ? true
              : state.realtimeUnavailable,
        ),
      ),
    );
  }

  Future<void> _subscribe(int operation) async {
    final previous = _subscription;
    _subscription = null;
    await previous?.cancel();
    if (_closing || isClosed || operation != _operation) return;
    _subscription = _listenToMessages().listen(
      (result) {
        if (_closing || isClosed) return;
        result.fold(
          (failure) => add(ChatStreamFailed(failure)),
          (message) => add(MessageReceived(message)),
        );
      },
      onError: (Object error) {
        if (!_closing && !isClosed) {
          add(
            const ChatStreamFailed(
              Failure(
                'Mất kết nối tin nhắn. Vui lòng kết nối lại.',
                connectionLost: true,
              ),
            ),
          );
        }
      },
    );
  }

  bool _active(int operation, Emitter<ChatState> emit) =>
      !_closing && operation == _operation && !emit.isDone;

  Future<void> _start(ChatStarted event, Emitter<ChatState> emit) async {
    if (state.sending) return;
    final operation = ++_operation;
    final changed = _targetUserId != event.targetUserId || _listMode;
    _targetUserId = event.targetUserId;
    _listMode = false;
    emit(
      state.copyWith(
        status: ChatStatus.loading,
        messages: changed ? [] : null,
        clearFailure: true,
        realtimeUnavailable: false,
      ),
    );
    await _subscribe(operation);
    if (!_active(operation, emit)) return;
    final result = await _getMessages(event.targetUserId);
    if (!_active(operation, emit)) return;
    if (result.data != null) {
      emit(
        state.copyWith(
          status: ChatStatus.loaded,
          // Keep messages received while the HTTP history was loading.
          messages: _merge(result.data!, state.messages),
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: ChatStatus.failure,
          failure: const Failure('Không tải được tin nhắn. Vui lòng thử lại.'),
        ),
      );
    }
  }

  Future<void> _loadConversations(
    ChatListStarted event,
    Emitter<ChatState> emit,
  ) async {
    final operation = ++_operation;
    final reconnect = _subscription == null || state.realtimeUnavailable;
    _listMode = true;
    _targetUserId = null;
    emit(
      state.copyWith(
        status: ChatStatus.loading,
        clearFailure: true,
        realtimeUnavailable: false,
      ),
    );
    if (reconnect) await _subscribe(operation);
    if (!_active(operation, emit)) return;
    final result = await _getConversations(null);
    if (!_active(operation, emit)) return;
    emit(
      result.data != null
          ? state.copyWith(
              status: ChatStatus.loaded,
              conversations: result.data!
                  .where((c) => c.lastMessage.trim().isNotEmpty)
                  .toList(),
            )
          : state.copyWith(
              status: ChatStatus.failure,
              failure: const Failure(
                'Không tải được hội thoại. Vui lòng thử lại.',
              ),
            ),
    );
  }

  bool _belongs(MessageResponse message) =>
      (message.senderId == session.accountId &&
          message.receiverId == _targetUserId) ||
      (message.senderId == _targetUserId &&
          message.receiverId == session.accountId);

  List<MessageResponse> _merge(
    List<MessageResponse> history,
    List<MessageResponse> live,
  ) {
    final byId = <String, MessageResponse>{
      for (final message in history.where(_belongs)) message.messageId: message,
      for (final message in live.where(_belongs)) message.messageId: message,
    };
    return byId.values.toList()..sort((a, b) {
      final time = a.updatedAt.compareTo(b.updatedAt);
      return time == 0 ? a.messageId.compareTo(b.messageId) : time;
    });
  }

  void _receive(MessageReceived event, Emitter<ChatState> emit) {
    if (_listMode) {
      if (event.message.senderId == session.accountId ||
          event.message.receiverId == session.accountId) {
        add(const ChatListStarted());
      }
      return;
    }
    if (!_belongs(event.message)) return;
    emit(
      state.copyWith(
        messages: _merge(state.messages, [event.message]),
        realtimeUnavailable: false,
        clearFailure: true,
      ),
    );
  }

  Future<void> _send(MessageSent event, Emitter<ChatState> emit) async {
    final target = _targetUserId;
    if (state.sending || state.status != ChatStatus.loaded || target == null) {
      return;
    }
    // New conversations must be opened via ContactLandlordButton.
    if (state.messages.isEmpty) {
      emit(
        state.copyWith(
          failure: const Failure('Hãy mở hội thoại từ trang chi tiết phòng.'),
        ),
      );
      return;
    }
    final content = event.content.trim();
    if (content.isEmpty || content.runes.length > 500) {
      emit(
        state.copyWith(
          failure: const Failure('Tin nhắn phải từ 1 đến 500 ký tự.'),
        ),
      );
      return;
    }
    final operation = _operation;
    emit(state.copyWith(sending: true, clearFailure: true));
    final result = await _sendMessage(
      ChatMessageRequest(
        type: 'chat_message',
        receiverId: target,
        content: content,
        status: 'active',
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    if (!_active(operation, emit)) return;
    if (result.data != true) {
      emit(
        state.copyWith(
          sending: false,
          failure: const Failure('Không gửi được tin nhắn. Vui lòng thử lại.'),
        ),
      );
      return;
    }
    // REST returns only id_valid, so fetch the server-assigned message ID.
    emit(state.copyWith(sentRevision: state.sentRevision + 1));
    final history = await _getMessages(target);
    if (!_active(operation, emit)) return;
    emit(
      state.copyWith(
        sending: false,
        messages: history.data == null
            ? null
            : _merge(history.data!, state.messages),
        failure: history.data == null
            ? const Failure(
                'Đã gửi. Chưa tải được lịch sử mới, hãy làm mới hội thoại.',
              )
            : null,
      ),
    );
  }

  @override
  Future<void> close() async {
    _closing = true;
    _operation++;
    await _subscription?.cancel();
    // The shared socket disconnects when its last listener leaves.
    return super.close();
  }
}
