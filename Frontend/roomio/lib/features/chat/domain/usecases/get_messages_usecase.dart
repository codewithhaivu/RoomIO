import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/chat/domain/entities/chat.dart';
import 'package:roomio/features/chat/domain/repository/chat_repository.dart';

class GetMessagesUseCase
    extends UseCase<DataState<List<MessageResponse>>, String> {
  final ChatRepository _repository;
  GetMessagesUseCase(this._repository);
  @override
  Future<DataState<List<MessageResponse>>> call(String params) =>
      _repository.getMessages(params);
}
