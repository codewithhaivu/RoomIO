import 'package:equatable/equatable.dart';
import 'package:roomio/features/appointment/domain/entities/appointment.dart';

abstract class RemoteAppointmentEvent extends Equatable {
  const RemoteAppointmentEvent();
  @override
  List<Object?> get props => [];
}

class GetAllAppointmentsEvent extends RemoteAppointmentEvent {
  const GetAllAppointmentsEvent();
}

/// Merge an appointment returned from the edit form without another GET.
class AppointmentChangedEvent extends RemoteAppointmentEvent {
  final AppointmentEntityResponse appointment;
  const AppointmentChangedEvent({required this.appointment});
  @override
  List<Object?> get props => [appointment];
}

class SendAppointmentEvent extends RemoteAppointmentEvent {
  final AppointmentEntityRequest request;
  const SendAppointmentEvent({required this.request});
  @override
  List<Object?> get props => [request];
}

class ConfirmAppointmentEvent extends RemoteAppointmentEvent {
  final String idAppointment;
  final String status;
  const ConfirmAppointmentEvent({
    required this.idAppointment,
    required this.status,
  });
  @override
  List<Object?> get props => [idAppointment, status];
}

class DestroyAppointmentEvent extends RemoteAppointmentEvent {
  final String idAppointment;
  const DestroyAppointmentEvent({required this.idAppointment});
  @override
  List<Object?> get props => [idAppointment];
}

class UpdateAppointmentEvent extends RemoteAppointmentEvent {
  final String idAppointment;
  final AppointmentEntityRequest request;
  const UpdateAppointmentEvent({
    required this.idAppointment,
    required this.request,
  });
  @override
  List<Object?> get props => [idAppointment, request];
}
