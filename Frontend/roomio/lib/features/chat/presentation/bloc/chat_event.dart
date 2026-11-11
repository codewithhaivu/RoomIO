import 'package:equatable/equatable.dart';
import 'package:roomio/core/error/failure.dart';
import 'package:roomio/features/chat/domain/entities/chat.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();
  @override
  List<Object?> get props => [];
}

class ChatStarted extends ChatEvent {
  final String targetUserId;
  const ChatStarted(this.targetUserId);
  @override
  List<Object?> get props => [targetUserId];
}

class ChatListStarted extends ChatEvent {
  const ChatListStarted();
}

class MessageReceived extends ChatEvent {
  final MessageEntity message;
  const MessageReceived(this.message);
  @override
  List<Object?> get props => [message];
}

class MessageSent extends ChatEvent {
  final String content;
  const MessageSent(this.content);
  @override
  List<Object?> get props => [content];
}

class ChatStreamFailed extends ChatEvent {
  final Failure failure;
  const ChatStreamFailed(this.failure);
  @override
  List<Object?> get props => [failure];
}
