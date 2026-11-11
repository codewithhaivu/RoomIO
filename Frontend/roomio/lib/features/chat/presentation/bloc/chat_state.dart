import 'package:equatable/equatable.dart';
import 'package:roomio/core/error/failure.dart';
import 'package:roomio/features/chat/domain/entities/chat.dart';

enum ChatStatus { initial, loading, loaded, failure }

class ChatState extends Equatable {
  final ChatStatus status;
  final List<MessageResponse> messages;
  final List<ConversationResponse> conversations;
  final bool sending;
  final bool realtimeUnavailable;
  final Failure? failure;
  final int sentRevision;

  const ChatState({
    this.status = ChatStatus.initial,
    this.messages = const [],
    this.conversations = const [],
    this.sending = false,
    this.realtimeUnavailable = false,
    this.failure,
    this.sentRevision = 0,
  });

  ChatState copyWith({
    ChatStatus? status,
    List<MessageResponse>? messages,
    List<ConversationResponse>? conversations,
    bool? sending,
    bool? realtimeUnavailable,
    Failure? failure,
    bool clearFailure = false,
    int? sentRevision,
  }) => ChatState(
    status: status ?? this.status,
    messages: messages == null ? this.messages : List.unmodifiable(messages),
    conversations: conversations == null
        ? this.conversations
        : List.unmodifiable(conversations),
    sending: sending ?? this.sending,
    realtimeUnavailable: realtimeUnavailable ?? this.realtimeUnavailable,
    failure: failure ?? (clearFailure ? null : this.failure),
    sentRevision: sentRevision ?? this.sentRevision,
  );

  @override
  List<Object?> get props => [
    status,
    messages,
    conversations,
    sending,
    realtimeUnavailable,
    failure,
    sentRevision,
  ];
}
