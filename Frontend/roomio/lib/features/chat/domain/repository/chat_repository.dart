import 'package:dartz/dartz.dart';
import 'package:roomio/core/error/failure.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/chat/domain/entities/chat.dart';

abstract class ChatRepository {
  Future<DataState<List<ConversationResponse>>> getConversations();
  Future<DataState<List<MessageResponse>>> getMessages(String targetUserId);
  Future<DataState<bool>> sendMessage(ChatMessageRequest request);
  Stream<Either<Failure, MessageEntity>> listenToMessages();

  // Compatibility with the original repository contract.
  Future<DataState<List<ConversationResponse>>> getConverstations() =>
      getConversations();
  Future<void> connectRealtime();
  Stream<MessageResponse> get incomingMessages;
  Future<void> disconnectRealtime();
}
