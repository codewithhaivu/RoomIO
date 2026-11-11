import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/appointment/domain/entities/appointment.dart';
import 'package:roomio/features/appointment/domain/repository/appointment_repository.dart';

class SendAppointmentUseCase
    extends
        UseCase<
          DataState<AppointmentEntityResponse>,
          AppointmentEntityRequest
        > {
  final AppointmentRepository _appointmentRepository;
  SendAppointmentUseCase(this._appointmentRepository);

  @override
  Future<DataState<AppointmentEntityResponse>> call(
    AppointmentEntityRequest params,
  ) async {
    return await _appointmentRepository.sendAppointment(params);
  }
}
