import 'dart:async';
import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:roomio/core/error/failure.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/chat/data/data_sources/remote/chat_api_service.dart';
import 'package:roomio/features/chat/data/data_sources/remote/chat_websocket_service.dart';
import 'package:roomio/features/chat/data/models/chat.dart';
import 'package:roomio/features/chat/domain/entities/chat.dart';
import 'package:roomio/features/chat/domain/repository/chat_repository.dart';

class ChatRepositoryImpl extends ChatRepository {
  final ChatApiService _api;
  final ChatWebSocketService _socket;
  ChatRepositoryImpl(this._api, this._socket);

  Future<DataState<T>> _request<R, T>(
    Future<HttpResponse<R>> Function() request,
    T Function(R) convert,
  ) async {
    try {
      final result = await request();
      final status = result.response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw DioException.badResponse(
          statusCode: status,
          requestOptions: result.response.requestOptions,
          response: result.response,
        );
      }
      return DataSuccess(convert(result.data));
    } on DioException catch (error) {
      return DataError(error);
    } catch (error) {
      return DataError(
        DioException(
          requestOptions: RequestOptions(path: '/chat'),
          error: error,
          message: 'Dữ liệu tin nhắn không hợp lệ.',
        ),
      );
    }
  }

  @override
  Future<DataState<List<ConversationResponse>>> getConversations() => _request(
    _api.getConversations,
    (result) =>
        result.data.where((c) => c.lastMessage.trim().isNotEmpty).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
  );

  @override
  Future<DataState<List<MessageResponse>>> getMessages(String targetUserId) =>
      _request(() => _api.getMessages(targetUserId), (result) => result.data);

  @override
  Future<DataState<bool>> sendMessage(ChatMessageRequest request) => _request(
    () => _api.sendMessage(
      ChatMessageModelRequest(
        type: request.type,
        receiverId: request.receiverId,
        content: request.content,
        status: request.status,
        updatedAt: request.updatedAt.toUtc(),
      ),
    ),
    (result) => result.isValid,
  );

  @override
  Stream<Either<Failure, MessageEntity>> listenToMessages() => Stream.multi((
    controller,
  ) {
    final subscription = _socket.messages.listen(
      (raw) {
        try {
          final Object? event = raw is String
              ? jsonDecode(raw)
              : raw is List<int>
              ? jsonDecode(utf8.decode(raw))
              : raw;
          if (event is! Map || event['type'] is! String) {
            throw const FormatException('Invalid event envelope');
          }
          // Notifications share this connection.
          if (event['type'] != 'chat_message') return;
          final data = event['data'];
          if (data is! Map) throw const FormatException('Missing message data');
          controller.add(
            Right(
              MessageModelResponse.fromJson(Map<String, dynamic>.from(data)),
            ),
          );
        } catch (_) {
          controller.add(const Left(Failure('Dữ liệu tin nhắn không hợp lệ.')));
        }
      },
      onError: (Object error) => controller.add(
        const Left(
          Failure(
            'Mất kết nối tin nhắn. Vui lòng kết nối lại.',
            connectionLost: true,
          ),
        ),
      ),
    );
    controller.onCancel = subscription.cancel;
    unawaited(
      _socket.connect().catchError((Object error) {
        if (!controller.isClosed) {
          controller.add(
            const Left(
              Failure(
                'Không thể kết nối tin nhắn. Vui lòng thử lại.',
                connectionLost: true,
              ),
            ),
          );
        }
      }),
    );
  }, isBroadcast: true);

  @override
  Future<void> connectRealtime() => _socket.connect();
  @override
  Future<void> disconnectRealtime() => _socket.disconnect();
  @override
  Stream<MessageResponse> get incomingMessages => listenToMessages().expand(
    (result) => result.fold((_) => <MessageResponse>[], (message) => [message]),
  );
}
