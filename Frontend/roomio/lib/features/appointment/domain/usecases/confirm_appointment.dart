import 'package:equatable/equatable.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/appointment/domain/repository/appointment_repository.dart';

class ConfirmAppointmentUseCase
    extends UseCase<DataState<String>, ConfirmAppointmentParams> {
  final AppointmentRepository _appointmentRepository;
  ConfirmAppointmentUseCase(this._appointmentRepository);

  @override
  Future<DataState<String>> call(ConfirmAppointmentParams params) async {
    return await _appointmentRepository.confirmAppointment(
      params.idAppointment,
      params.status,
    );
  }
}

class ConfirmAppointmentParams extends Equatable {
  final String idAppointment;
  final String status;
  const ConfirmAppointmentParams({
    required this.idAppointment,
    required this.status,
  });
  @override
  List<Object?> get props => [idAppointment, status];
}
