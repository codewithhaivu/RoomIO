import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:roomio/core/constants/constants.dart';
import 'package:roomio/features/chat/data/models/chat.dart';

part 'chat_api_service.g.dart';

@RestApi(baseUrl: chatAPIBaseUrl)
abstract class ChatApiService {
  factory ChatApiService(Dio dio, {String baseUrl}) = _ChatApiService;
  @GET('/conversations')
  Future<HttpResponse<ListConversationModelResposne>> getConversations();

  @GET('/messages/{target_user_id}')
  Future<HttpResponse<ListMessageModelResponse>> getMessages(
    @Path('target_user_id') String targetUserId,
  );
  @POST('/messages')
  Future<HttpResponse<ChatMessageModelResponse>> sendMessage(
    @Body() ChatMessageModelRequest request,
  );
}
