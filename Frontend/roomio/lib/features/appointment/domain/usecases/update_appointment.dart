import 'package:equatable/equatable.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/appointment/domain/entities/appointment.dart';
import 'package:roomio/features/appointment/domain/repository/appointment_repository.dart';

class UpdateAppointmentUseCase
    extends UseCase<DataState<String>, UpdateAppointmentParams> {
  final AppointmentRepository _appointmentRepository;
  UpdateAppointmentUseCase(this._appointmentRepository);

  @override
  Future<DataState<String>> call(UpdateAppointmentParams params) async {
    return await _appointmentRepository.updateAppointment(
      params.idAppointment,
      params.request,
    );
  }
}

class UpdateAppointmentParams extends Equatable {
  final String idAppointment;
  final AppointmentEntityRequest request;
  const UpdateAppointmentParams({
    required this.idAppointment,
    required this.request,
  });
  @override
  List<Object?> get props => [idAppointment, request];
}
