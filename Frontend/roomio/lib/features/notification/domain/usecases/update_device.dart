import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/notification/domain/repository/notification_repository.dart';

class UpdateDeviceUseCase
    extends UseCase<DataState<String>, ({String fcmToken, String idDevice})> {
  final NotificationRepository _repository;

  UpdateDeviceUseCase(this._repository);

  @override
  Future<DataState<String>> call(({String fcmToken, String idDevice}) params) =>
      _repository.updateDevice(params.fcmToken, params.idDevice);
}
