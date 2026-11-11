import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/chat/domain/entities/chat.dart';
import 'package:roomio/features/chat/domain/repository/chat_repository.dart';

class GetConversationsUseCase
    extends UseCase<DataState<List<ConversationResponse>>, void> {
  final ChatRepository _repository;
  GetConversationsUseCase(this._repository);
  @override
  Future<DataState<List<ConversationResponse>>> call(void params) =>
      _repository.getConversations();
}
