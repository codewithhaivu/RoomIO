import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/appointment/domain/entities/appointment.dart';
import 'package:roomio/features/appointment/domain/repository/appointment_repository.dart';

class GetAllAppointmentsUseCase
    extends UseCase<DataState<List<AppointmentEntityResponse>>, void> {
  final AppointmentRepository _appointmentRepository;
  GetAllAppointmentsUseCase(this._appointmentRepository);

  @override
  Future<DataState<List<AppointmentEntityResponse>>> call(void params) async {
    return await _appointmentRepository.getAllAppointments();
  }
}
