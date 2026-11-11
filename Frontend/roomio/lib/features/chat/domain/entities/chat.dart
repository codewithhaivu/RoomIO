import 'package:equatable/equatable.dart';

typedef MessageEntity = MessageResponse;

class ChatSession {
  final String accountId;
  final String role;
  const ChatSession({required this.accountId, required this.role});
  bool get isTenant => role == 'CUSTOMER' || role == 'TENANT';
}

class ConversationResponse extends Equatable {
  final String targetUserId;
  final String targetUserName;
  final String? targetAvatarUrl;
  final String lastMessage;
  final DateTime updatedAt;

  const ConversationResponse({
    required this.targetUserId,
    required this.targetUserName,
    this.targetAvatarUrl,
    required this.lastMessage,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
    targetUserId,
    targetUserName,
    targetAvatarUrl,
    lastMessage,
    updatedAt,
  ];
}

class MessageResponse extends Equatable {
  final String messageId;
  final String senderId;
  final String receiverId;
  final String content;
  final String status;
  final DateTime updatedAt;

  const MessageResponse({
    required this.messageId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.status,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
    messageId,
    senderId,
    receiverId,
    content,
    status,
    updatedAt,
  ];
}

class ChatMessageRequest extends Equatable {
  final String type;
  final String receiverId;
  final String content;
  final String status;
  final DateTime updatedAt;

  const ChatMessageRequest({
    required this.type,
    required this.receiverId,
    required this.content,
    required this.status,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [type, receiverId, content, status, updatedAt];
}
