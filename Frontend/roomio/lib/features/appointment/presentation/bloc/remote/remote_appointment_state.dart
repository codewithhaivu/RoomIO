import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:roomio/features/appointment/domain/entities/appointment.dart';

enum RemoteAppointmentStatus {
  initial,
  loading,
  loaded,
  submitting,
  sent,
  success,
  failure,
}

class RemoteAppointmentState extends Equatable {
  final List<AppointmentEntityResponse>? appointments;
  final RemoteAppointmentStatus requestStatus;
  final AppointmentEntityResponse? appointment;
  final String? message;
  final DioException? dio;

  const RemoteAppointmentState({
    this.appointments,
    this.requestStatus = RemoteAppointmentStatus.initial,
    this.appointment,
    this.message,
    this.dio,
  });

  bool get isBusy =>
      requestStatus == RemoteAppointmentStatus.loading ||
      requestStatus == RemoteAppointmentStatus.submitting;

  RemoteAppointmentState copyWith({
    List<AppointmentEntityResponse>? appointments,
    RemoteAppointmentStatus? requestStatus,
    AppointmentEntityResponse? appointment,
    String? message,
    DioException? dio,
    bool clearResult = false,
  }) => RemoteAppointmentState(
    appointments: appointments == null
        ? this.appointments
        : List.unmodifiable(appointments),
    requestStatus: requestStatus ?? this.requestStatus,
    appointment: appointment ?? (clearResult ? null : this.appointment),
    message: message ?? (clearResult ? null : this.message),
    dio: dio ?? (clearResult ? null : this.dio),
  );

  @override
  List<Object?> get props => [
    appointments,
    requestStatus,
    appointment,
    message,
    dio,
  ];
}
