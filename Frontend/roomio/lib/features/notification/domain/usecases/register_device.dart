import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/notification/domain/repository/notification_repository.dart';

class RegisterDeviceUseCase
    extends UseCase<DataState<String>, ({String fcmToken, String platform})> {
  final NotificationRepository _repository;

  RegisterDeviceUseCase(this._repository);

  @override
  Future<DataState<String>> call(({String fcmToken, String platform}) params) =>
      _repository.registerDevice(params.fcmToken, params.platform);
}
