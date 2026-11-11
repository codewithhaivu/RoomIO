import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/notification/domain/repository/notification_repository.dart';

class MarkNotificationReadUseCase extends UseCase<DataState<String>, String> {
  final NotificationRepository _repository;
  MarkNotificationReadUseCase(this._repository);
  @override
  Future<DataState<String>> call(String params) =>
      _repository.markNotifications(params);
}
