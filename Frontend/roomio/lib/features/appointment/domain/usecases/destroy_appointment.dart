import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/appointment/domain/repository/appointment_repository.dart';

class DestroyAppointmentUseCase extends UseCase<DataState<String>, String> {
  final AppointmentRepository _appointmentRepository;
  DestroyAppointmentUseCase(this._appointmentRepository);

  @override
  Future<DataState<String>> call(String params) async {
    return await _appointmentRepository.destroyAppointment(params);
  }
}
