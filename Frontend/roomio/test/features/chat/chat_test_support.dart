import 'dart:async';
import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:roomio/core/error/failure.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/chat/data/data_sources/remote/chat_api_service.dart';
import 'package:roomio/features/chat/data/data_sources/remote/chat_websocket_service.dart';
import 'package:roomio/features/chat/data/repository/chat_repository_impl.dart';
import 'package:roomio/features/chat/domain/entities/chat.dart';
import 'package:roomio/features/chat/domain/repository/chat_repository.dart';
import 'package:roomio/features/chat/domain/usecases/get_conversations_usecase.dart';
import 'package:roomio/features/chat/domain/usecases/get_messages_usecase.dart';
import 'package:roomio/features/chat/domain/usecases/listen_to_messages_usecase.dart';
import 'package:roomio/features/chat/domain/usecases/send_message_usecase.dart';
import 'package:roomio/features/chat/presentation/bloc/chat_bloc.dart';

const tenant = ChatSession(accountId: 'tenant-id', role: 'CUSTOMER');
const landlord = ChatSession(accountId: 'landlord-id', role: 'LANDLORD');

Map<String, dynamic> messageJson([String id = 'message-1']) => {
  'message_id': id,
  'sender_id': 'tenant-id',
  'receiver_id': 'landlord-id',
  'content': 'Phòng còn trống không?',
  'status': 'active',
  'created_at': '2030-01-01T02:00:00Z',
};

MessageResponse message({
  String id = 'message-1',
  String sender = 'tenant-id',
  String receiver = 'landlord-id',
  String content = 'Phòng còn trống không?',
  int minute = 0,
}) => MessageResponse(
  messageId: id,
  senderId: sender,
  receiverId: receiver,
  content: content,
  status: 'active',
  updatedAt: DateTime.utc(2030, 1, 1, 2, minute),
);

ConversationResponse conversation({
  String target = 'landlord-id',
  String text = 'Phòng còn trống không?',
}) => ConversationResponse(
  targetUserId: target,
  targetUserName: 'Chủ trọ An',
  lastMessage: text,
  updatedAt: DateTime.utc(2030),
);

String sessionToken(String id) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': id})))}.signature';

ChatBloc chatBloc(
  FakeChatRepository repository, {
  ChatSession session = tenant,
}) => ChatBloc(
  GetMessagesUseCase(repository),
  SendMessageUseCase(repository),
  ListenToMessagesUseCase(repository),
  GetConversationsUseCase(repository),
  session,
);

class FakeChatRepository extends ChatRepository {
  List<MessageResponse> history = [message()];
  List<ConversationResponse> conversations = [conversation()];
  final events = StreamController<Either<Failure, MessageEntity>>.broadcast();
  final sent = <ChatMessageRequest>[];
  final historyLoads = <Completer<DataState<List<MessageResponse>>>>[];
  Completer<DataState<bool>>? pendingSend;
  DioException? historyError;
  DioException? sendError;
  bool sendValid = true;
  int historyCalls = 0;
  int listCalls = 0;
  int listenCalls = 0;

  @override
  Future<DataState<List<ConversationResponse>>> getConversations() async {
    listCalls++;
    return DataSuccess(conversations);
  }

  @override
  Future<DataState<List<MessageResponse>>> getMessages(
    String targetUserId,
  ) async {
    final index = historyCalls++;
    if (index < historyLoads.length) return historyLoads[index].future;
    if (historyError != null) return DataError(historyError!);
    return DataSuccess(List.of(history));
  }

  @override
  Future<DataState<bool>> sendMessage(ChatMessageRequest request) async {
    sent.add(request);
    if (pendingSend != null) return pendingSend!.future;
    if (sendError != null) return DataError(sendError!);
    if (sendValid) {
      history = [
        ...history,
        message(
          id: 'sent-${sent.length}',
          sender: 'tenant-id',
          receiver: request.receiverId,
          content: request.content,
          minute: sent.length,
        ),
      ];
    }
    return DataSuccess(sendValid);
  }

  @override
  Stream<Either<Failure, MessageEntity>> listenToMessages() {
    listenCalls++;
    return events.stream;
  }

  @override
  Future<void> connectRealtime() async {}
  @override
  Future<void> disconnectRealtime() async {}
  @override
  Stream<MessageResponse> get incomingMessages => events.stream.expand(
    (event) => event.fold((_) => <MessageResponse>[], (m) => [m]),
  );
}

class FakeChatSocket extends ChatWebSocketService {
  final events = StreamController<dynamic>.broadcast();
  int connections = 0;
  Object? connectError;
  FakeChatSocket() : super(const FlutterSecureStorage());
  @override
  Stream<dynamic> get messages => events.stream;
  @override
  Future<void> connect() async {
    connections++;
    if (connectError != null) throw connectError!;
  }

  @override
  Future<void> disconnect() async {}
}

class ChatTestApi {
  final dio = Dio(BaseOptions(validateStatus: (_) => true));
  final socket = FakeChatSocket();
  late final ChatRepositoryImpl repository;
  Object? data;
  int statusCode = 200;
  DioException? error;
  final requests = <RequestOptions>[];

  ChatTestApi() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          if (error != null) {
            handler.reject(error!);
          } else {
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: statusCode,
                data: data,
              ),
            );
          }
        },
      ),
    );
    repository = ChatRepositoryImpl(ChatApiService(dio), socket);
  }
  Future<void> dispose() async {
    dio.close(force: true);
    await socket.events.close();
  }
}
