import 'package:roomio/features/chat/domain/entities/chat.dart';

DateTime _chatTime(String value) {
  final parsed = DateTime.parse(value);
  // The backend stores UTC but older conversation timestamps omit the offset.
  return parsed.isUtc || RegExp(r'[+-]\d\d:\d\d$').hasMatch(value)
      ? parsed.toUtc()
      : DateTime.parse('${value}Z');
}

class ConverStationModelResponse extends ConversationResponse {
  const ConverStationModelResponse({
    required super.targetUserId,
    required super.targetUserName,
    super.targetAvatarUrl,
    required super.lastMessage,
    required super.updatedAt,
  });

  factory ConverStationModelResponse.fromJson(Map<String, dynamic> json) {
    return ConverStationModelResponse(
      targetUserId: json['target_user_id'] as String,
      targetUserName: json['target_user_name'] as String,
      targetAvatarUrl: json['target_avatar_url'] as String? ?? '',
      lastMessage: json['last_message'] as String,
      updatedAt: _chatTime(json['updated_at'] as String),
    );
  }
}

class MessageModelResponse extends MessageResponse {
  const MessageModelResponse({
    required super.messageId,
    required super.senderId,
    required super.receiverId,
    required super.content,
    required super.status,
    required super.updatedAt,
  });

  factory MessageModelResponse.fromJson(Map<String, dynamic> json) {
    return MessageModelResponse(
      messageId: json['message_id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      content: json['content'] as String,
      status: json['status'] as String,
      updatedAt: _chatTime(json['created_at'] as String),
    );
  }
}

class ChatMessageModelRequest extends ChatMessageRequest {
  const ChatMessageModelRequest({
    required super.type,
    required super.receiverId,
    required super.content,
    required super.status,
    required super.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'receiver_id': receiverId,
      'content': content,
      'status': status,
      'created_at': updatedAt.toIso8601String(),
    };
  }
}

class ListConversationModelResposne {
  final List<ConverStationModelResponse> data;
  const ListConversationModelResposne({required this.data});
  factory ListConversationModelResposne.fromJson(
    Map<String, dynamic> json,
  ) => ListConversationModelResposne(
    data: (json['data'] as List<dynamic>)
        .map(
          (item) =>
              ConverStationModelResponse.fromJson(item as Map<String, dynamic>),
        )
        .toList(),
  );
}

class ListMessageModelResponse {
  final List<MessageModelResponse> data;
  const ListMessageModelResponse({required this.data});
  factory ListMessageModelResponse.fromJson(Map<String, dynamic> json) =>
      ListMessageModelResponse(
        data: (json['data'] as List<dynamic>)
            .map(
              (item) =>
                  MessageModelResponse.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
      );
}

class ChatMessageModelResponse {
  final bool isValid;
  const ChatMessageModelResponse({required this.isValid});

  factory ChatMessageModelResponse.fromJson(Map<String, dynamic> json) =>
      ChatMessageModelResponse(isValid: json['id_valid'] as bool);
}
