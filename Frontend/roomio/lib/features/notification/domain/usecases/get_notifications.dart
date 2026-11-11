import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/notification/domain/entities/notification.dart';
import 'package:roomio/features/notification/domain/repository/notification_repository.dart';

class GetNotificationsUseCase
    extends UseCase<DataState<List<NotificationResponse>>, int> {
  final NotificationRepository _repository;
  GetNotificationsUseCase(this._repository);
  @override
  Future<DataState<List<NotificationResponse>>> call(int params) =>
      _repository.getNotifications(params);
}
