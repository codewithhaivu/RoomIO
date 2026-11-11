import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/chat/domain/entities/chat.dart';
import 'package:roomio/features/chat/domain/repository/chat_repository.dart';

class SendMessageUseCase extends UseCase<DataState<bool>, ChatMessageRequest> {
  final ChatRepository _repository;
  SendMessageUseCase(this._repository);
  @override
  Future<DataState<bool>> call(ChatMessageRequest params) =>
      _repository.sendMessage(params);
}
