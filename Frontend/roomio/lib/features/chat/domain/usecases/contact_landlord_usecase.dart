import 'package:dartz/dartz.dart';
import 'package:roomio/core/error/failure.dart';
import 'package:roomio/features/chat/domain/entities/chat.dart';
import 'package:roomio/features/chat/domain/repository/chat_repository.dart';

/// The backend atomically creates/reuses the conversation in POST /messages.
class ContactLandlordUseCase {
  final ChatRepository _repository;
  ContactLandlordUseCase(this._repository);

  Future<Either<Failure, bool>> call({
    required ChatSession session,
    required String landlordAccountId,
    String? firstMessage,
  }) async {
    if (!session.isTenant) {
      return const Left(Failure('Chỉ khách thuê được bắt đầu hội thoại.'));
    }
    if (landlordAccountId.trim().isEmpty ||
        landlordAccountId == session.accountId) {
      return const Left(Failure('Thông tin chủ trọ không hợp lệ.'));
    }
    final history = await _repository.getMessages(landlordAccountId);
    if (history.error != null) {
      return const Left(
        Failure('Không thể kiểm tra hội thoại. Vui lòng thử lại.'),
      );
    }
    if (history.data!.isNotEmpty && firstMessage == null) {
      return const Right(true);
    }
    // false asks the room-detail widget to collect the first message.
    if (firstMessage == null) return const Right(false);
    final content = firstMessage.trim();
    if (content.isEmpty || content.runes.length > 500) {
      return const Left(Failure('Tin nhắn phải từ 1 đến 500 ký tự.'));
    }
    final sent = await _repository.sendMessage(
      ChatMessageRequest(
        type: 'chat_message',
        receiverId: landlordAccountId,
        content: content,
        status: 'active',
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    return sent.data == true
        ? const Right(true)
        : const Left(Failure('Không gửi được tin nhắn. Vui lòng thử lại.'));
  }
}
