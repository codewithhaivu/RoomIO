import 'package:dartz/dartz.dart';
import 'package:roomio/core/error/failure.dart';
import 'package:roomio/features/chat/domain/entities/chat.dart';
import 'package:roomio/features/chat/domain/repository/chat_repository.dart';

/// A stream use case deliberately does not extend the Future-based UseCase.
class ListenToMessagesUseCase {
  final ChatRepository _repository;
  ListenToMessagesUseCase(this._repository);
  Stream<Either<Failure, MessageEntity>> call() =>
      _repository.listenToMessages();
}
