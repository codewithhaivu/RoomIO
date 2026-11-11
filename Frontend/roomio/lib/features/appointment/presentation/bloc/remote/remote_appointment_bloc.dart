import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/appointment/domain/entities/appointment.dart';
import 'package:roomio/features/appointment/domain/usecases/confirm_appointment.dart';
import 'package:roomio/features/appointment/domain/usecases/destroy_appointment.dart';
import 'package:roomio/features/appointment/domain/usecases/get_all_appointments.dart';
import 'package:roomio/features/appointment/domain/usecases/send_appointment.dart';
import 'package:roomio/features/appointment/domain/usecases/update_appointment.dart';
import 'package:roomio/features/appointment/presentation/bloc/remote/remote_appointment_event.dart';
import 'package:roomio/features/appointment/presentation/bloc/remote/remote_appointment_state.dart';

class RemoteAppointmentBloc
    extends Bloc<RemoteAppointmentEvent, RemoteAppointmentState> {
  final SendAppointmentUseCase _sendAppointmentUseCase;
  final GetAllAppointmentsUseCase _getAllAppointmentsUseCase;
  final ConfirmAppointmentUseCase _confirmAppointmentUseCase;
  final DestroyAppointmentUseCase _destroyAppointmentUseCase;
  final UpdateAppointmentUseCase _updateAppointmentUseCase;
  bool _submitting = false;
  int _loadRevision = 0;

  RemoteAppointmentBloc(
    this._sendAppointmentUseCase,
    this._getAllAppointmentsUseCase,
    this._confirmAppointmentUseCase,
    this._destroyAppointmentUseCase,
    this._updateAppointmentUseCase,
  ) : super(const RemoteAppointmentState()) {
    on<GetAllAppointmentsEvent>(getAllAppointments);
    on<SendAppointmentEvent>(sendAppointment);
    on<ConfirmAppointmentEvent>(confirmAppointment);
    on<DestroyAppointmentEvent>(destroyAppointment);
    on<UpdateAppointmentEvent>(updateAppointment);
    on<AppointmentChangedEvent>(appointmentChanged);
  }

  Future<void> getAllAppointments(
    GetAllAppointmentsEvent event,
    Emitter<RemoteAppointmentState> emit,
  ) async {
    if (_submitting) return;
    final revision = ++_loadRevision;
    emit(
      state.copyWith(
        requestStatus: RemoteAppointmentStatus.loading,
        clearResult: true,
      ),
    );
    final result = await _getAllAppointmentsUseCase(null);
    if (emit.isDone || revision != _loadRevision) return;
    emit(
      result is DataSuccess
          ? state.copyWith(
              requestStatus: RemoteAppointmentStatus.loaded,
              appointments: result.data!,
            )
          : state.copyWith(
              requestStatus: RemoteAppointmentStatus.failure,
              dio: result.error!,
            ),
    );
  }

  Future<void> sendAppointment(
    SendAppointmentEvent event,
    Emitter<RemoteAppointmentState> emit,
  ) async {
    if (_submitting) return;
    _submitting = true;
    ++_loadRevision;
    emit(
      state.copyWith(
        requestStatus: RemoteAppointmentStatus.submitting,
        clearResult: true,
      ),
    );
    try {
      final result = await _sendAppointmentUseCase(event.request);
      if (emit.isDone) return;
      emit(
        result is DataSuccess
            ? state.copyWith(
                requestStatus: RemoteAppointmentStatus.sent,
                appointment: result.data!,
              )
            : state.copyWith(
                requestStatus: RemoteAppointmentStatus.failure,
                dio: result.error!,
              ),
      );
    } finally {
      _submitting = false;
    }
  }

  Future<void> confirmAppointment(
    ConfirmAppointmentEvent event,
    Emitter<RemoteAppointmentState> emit,
  ) => _submitMessage(
    () => _confirmAppointmentUseCase(
      ConfirmAppointmentParams(
        idAppointment: event.idAppointment,
        status: event.status,
      ),
    ),
    emit,
    (appointments) => appointments
        .map(
          (appointment) => appointment.idAppointment == event.idAppointment
              ? appointment.copyWith(status: event.status)
              : appointment,
        )
        .toList(),
  );

  Future<void> destroyAppointment(
    DestroyAppointmentEvent event,
    Emitter<RemoteAppointmentState> emit,
  ) => _submitMessage(
    () => _destroyAppointmentUseCase(event.idAppointment),
    emit,
    (appointments) => appointments
        .where(
          (appointment) => appointment.idAppointment != event.idAppointment,
        )
        .toList(),
  );

  Future<void> updateAppointment(
    UpdateAppointmentEvent event,
    Emitter<RemoteAppointmentState> emit,
  ) => _submitMessage(
    () => _updateAppointmentUseCase(
      UpdateAppointmentParams(
        idAppointment: event.idAppointment,
        request: event.request,
      ),
    ),
    emit,
    (appointments) => appointments
        .map(
          (appointment) => appointment.idAppointment == event.idAppointment
              ? appointment.copyWith(
                  meetAt: event.request.meetAt,
                  status: 'PENDING',
                )
              : appointment,
        )
        .toList(),
  );

  void appointmentChanged(
    AppointmentChangedEvent event,
    Emitter<RemoteAppointmentState> emit,
  ) {
    // Applying a completed edit also invalidates any older in-flight list response.
    ++_loadRevision;
    final appointments = [...?state.appointments];
    final index = appointments.indexWhere(
      (item) => item.idAppointment == event.appointment.idAppointment,
    );
    if (index == -1) {
      appointments.add(event.appointment);
    } else {
      appointments[index] = event.appointment;
    }
    emit(
      state.copyWith(
        appointments: appointments,
        requestStatus: RemoteAppointmentStatus.loaded,
        clearResult: true,
      ),
    );
  }

  Future<void> _submitMessage(
    Future<DataState<String>> Function() action,
    Emitter<RemoteAppointmentState> emit,
    List<AppointmentEntityResponse> Function(List<AppointmentEntityResponse>)
    update,
  ) async {
    if (_submitting) return;
    _submitting = true;
    ++_loadRevision;
    emit(
      state.copyWith(
        requestStatus: RemoteAppointmentStatus.submitting,
        clearResult: true,
      ),
    );
    try {
      final result = await action();
      if (emit.isDone) return;
      emit(
        result is DataSuccess
            ? state.copyWith(
                requestStatus: RemoteAppointmentStatus.success,
                message: result.data!,
                appointments: state.appointments == null
                    ? null
                    : update(state.appointments!),
              )
            : state.copyWith(
                requestStatus: RemoteAppointmentStatus.failure,
                dio: result.error!,
              ),
      );
    } finally {
      _submitting = false;
    }
  }
}
