import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/appointment/domain/entities/appointment.dart';
import 'package:roomio/features/appointment/presentation/bloc/remote/remote_appointment_bloc.dart';
import 'package:roomio/features/appointment/presentation/bloc/remote/remote_appointment_event.dart';
import 'package:roomio/features/appointment/presentation/bloc/remote/remote_appointment_state.dart';
import 'appointment_test_support.dart';

Future<void> dispatch(
  RemoteAppointmentBloc bloc,
  RemoteAppointmentEvent event,
  List<Object> states,
) async {
  final expectation = expectLater(bloc.stream, emitsInOrder(states));
  bloc.add(event);
  await expectation;
}

Matcher hasStatus(RemoteAppointmentStatus status) =>
    isA<RemoteAppointmentState>().having(
      (state) => state.requestStatus,
      'requestStatus',
      status,
    );

void main() {
  late FakeAppointmentRepository repository;
  late RemoteAppointmentBloc bloc;
  setUp(() {
    repository = FakeAppointmentRepository();
    bloc = appointmentBloc(repository);
  });
  tearDown(() => bloc.close());

  test('loads the list through its use case', () async {
    await dispatch(bloc, const GetAllAppointmentsEvent(), [
      hasStatus(RemoteAppointmentStatus.loading),
      hasStatus(RemoteAppointmentStatus.loaded),
    ]);
    expect(bloc.state.appointments, [appointment]);
  });

  test(
    'create, update and cancellation forward exact room/appointment parameters',
    () async {
      await dispatch(bloc, SendAppointmentEvent(request: appointmentRequest), [
        hasStatus(RemoteAppointmentStatus.submitting),
        hasStatus(RemoteAppointmentStatus.sent),
      ]);
      expect(repository.request, appointmentRequest);
      await dispatch(
        bloc,
        UpdateAppointmentEvent(
          idAppointment: 'appointment-id',
          request: appointmentRequest,
        ),
        [
          hasStatus(RemoteAppointmentStatus.submitting),
          hasStatus(RemoteAppointmentStatus.success),
        ],
      );
      await dispatch(
        bloc,
        const DestroyAppointmentEvent(idAppointment: 'appointment-id'),
        [
          hasStatus(RemoteAppointmentStatus.submitting),
          hasStatus(RemoteAppointmentStatus.success),
        ],
      );
      expect(repository.actions, [
        'PATCH/appointment-id',
        'DELETE/appointment-id',
      ]);
    },
  );

  test('all supported landlord actions are forwarded', () async {
    for (final status in ['CONFIRMED', 'REJECTED']) {
      await dispatch(
        bloc,
        ConfirmAppointmentEvent(
          idAppointment: 'appointment-id',
          status: status,
        ),
        [
          hasStatus(RemoteAppointmentStatus.submitting),
          hasStatus(RemoteAppointmentStatus.success),
        ],
      );
    }
    expect(repository.actions, [
      'appointment-id/CONFIRMED',
      'appointment-id/REJECTED',
    ]);
  });

  test('failure preserves an already loaded list for retry', () async {
    await dispatch(bloc, const GetAllAppointmentsEvent(), [
      hasStatus(RemoteAppointmentStatus.loading),
      hasStatus(RemoteAppointmentStatus.loaded),
    ]);
    repository.error = DioException(
      requestOptions: RequestOptions(),
      type: DioExceptionType.connectionError,
    );
    await dispatch(
      bloc,
      const DestroyAppointmentEvent(idAppointment: 'appointment-id'),
      [
        hasStatus(RemoteAppointmentStatus.submitting),
        hasStatus(RemoteAppointmentStatus.failure),
      ],
    );
    expect(bloc.state.appointments, [appointment]);
    repository.error = null;
    await dispatch(
      bloc,
      const DestroyAppointmentEvent(idAppointment: 'appointment-id'),
      [
        hasStatus(RemoteAppointmentStatus.submitting),
        hasStatus(RemoteAppointmentStatus.success),
      ],
    );
  });

  test('double submission makes only one create request', () async {
    repository.sending = Completer<DataState<AppointmentEntityResponse>>();
    final pending = expectLater(
      bloc.stream,
      emitsInOrder([
        hasStatus(RemoteAppointmentStatus.submitting),
        hasStatus(RemoteAppointmentStatus.sent),
      ]),
    );
    bloc.add(SendAppointmentEvent(request: appointmentRequest));
    bloc.add(SendAppointmentEvent(request: appointmentRequest));
    await Future<void>.delayed(Duration.zero);
    expect(repository.sendCalls, 1);
    repository.sending!.complete(DataSuccess(appointment));
    await pending;
  });

  test('an older GET cannot overwrite a newer result', () async {
    final old = Completer<DataState<List<AppointmentEntityResponse>>>();
    final latest = Completer<DataState<List<AppointmentEntityResponse>>>();
    repository.loads.addAll([old, latest]);
    bloc.add(const GetAllAppointmentsEvent());
    await Future<void>.delayed(Duration.zero);
    final loaded = bloc.stream.firstWhere(
      (state) => state.requestStatus == RemoteAppointmentStatus.loaded,
    );
    bloc.add(const GetAllAppointmentsEvent());
    await Future<void>.delayed(Duration.zero);
    latest.complete(const DataSuccess([]));
    await loaded;
    old.complete(DataSuccess([appointment]));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.appointments, isEmpty);
  });

  test('a stale list response cannot replace a mutation result', () async {
    final old = Completer<DataState<List<AppointmentEntityResponse>>>();
    repository.loads.add(old);
    bloc.add(const GetAllAppointmentsEvent());
    await Future<void>.delayed(Duration.zero);
    final mutated = bloc.stream.firstWhere(
      (state) => state.requestStatus == RemoteAppointmentStatus.success,
    );
    bloc.add(const DestroyAppointmentEvent(idAppointment: 'appointment-id'));
    await mutated;
    old.complete(DataSuccess([appointment]));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state, hasStatus(RemoteAppointmentStatus.success));
  });

  for (final status in ['CONFIRMED', 'REJECTED']) {
    test(
      '$status updates only its matching item and preserves the old snapshot without GET',
      () async {
        final other = AppointmentEntityResponse(
          idRoom: 'other-room',
          meetAt: appointment.meetAt,
          idAppointment: 'other-id',
          nameRoom: 'Other room',
          nameTenant: 'Other tenant',
        );
        repository.appointments = [appointment, other];
        await dispatch(bloc, const GetAllAppointmentsEvent(), [
          hasStatus(RemoteAppointmentStatus.loading),
          hasStatus(RemoteAppointmentStatus.loaded),
        ]);
        final before = bloc.state;
        await dispatch(
          bloc,
          ConfirmAppointmentEvent(
            idAppointment: 'appointment-id',
            status: status,
          ),
          [
            hasStatus(RemoteAppointmentStatus.submitting),
            hasStatus(RemoteAppointmentStatus.success),
          ],
        );
        expect(bloc.state.appointments!.first.status, status);
        expect(bloc.state.appointments!.last, same(other));
        expect(before.appointments!.first.status, 'PENDING');
        expect(bloc.state.appointments, isNot(same(before.appointments)));
        expect(() => bloc.state.appointments!.clear(), throwsUnsupportedError);
        expect(repository.listCalls, 1);
      },
    );
  }

  test(
    'cancel removes only its matching id and never refetches the list',
    () async {
      final other = AppointmentEntityResponse(
        idRoom: 'other-room',
        meetAt: appointment.meetAt,
        idAppointment: 'other-id',
        nameRoom: 'Other room',
        nameTenant: 'Other tenant',
      );
      repository.appointments = [appointment, other];
      await dispatch(bloc, const GetAllAppointmentsEvent(), [
        hasStatus(RemoteAppointmentStatus.loading),
        hasStatus(RemoteAppointmentStatus.loaded),
      ]);
      final before = bloc.state;
      await dispatch(
        bloc,
        const DestroyAppointmentEvent(idAppointment: 'appointment-id'),
        [
          hasStatus(RemoteAppointmentStatus.submitting),
          hasStatus(RemoteAppointmentStatus.success),
        ],
      );
      expect(bloc.state.appointments, [other]);
      expect(before.appointments!.length, 2);
      expect(repository.listCalls, 1);
    },
  );

  test(
    'a failed confirm leaves all statuses unchanged without refetching',
    () async {
      await dispatch(bloc, const GetAllAppointmentsEvent(), [
        hasStatus(RemoteAppointmentStatus.loading),
        hasStatus(RemoteAppointmentStatus.loaded),
      ]);
      final before = bloc.state.appointments;
      repository.error = DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.connectionError,
      );
      await dispatch(
        bloc,
        const ConfirmAppointmentEvent(
          idAppointment: 'appointment-id',
          status: 'REJECTED',
        ),
        [
          hasStatus(RemoteAppointmentStatus.submitting),
          hasStatus(RemoteAppointmentStatus.failure),
        ],
      );
      expect(bloc.state.appointments, same(before));
      expect(bloc.state.appointments!.single.status, 'PENDING');
      expect(repository.listCalls, 1);
    },
  );

  test(
    'confirm waits for API success and suppresses duplicate mutation',
    () async {
      await dispatch(bloc, const GetAllAppointmentsEvent(), [
        hasStatus(RemoteAppointmentStatus.loading),
        hasStatus(RemoteAppointmentStatus.loaded),
      ]);
      repository.mutating = Completer<DataState<String>>();
      final pending = bloc.stream.firstWhere(
        (state) => state.requestStatus == RemoteAppointmentStatus.success,
      );
      bloc.add(
        const ConfirmAppointmentEvent(
          idAppointment: 'appointment-id',
          status: 'CONFIRMED',
        ),
      );
      bloc.add(
        const ConfirmAppointmentEvent(
          idAppointment: 'appointment-id',
          status: 'CONFIRMED',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.appointments!.single.status, 'PENDING');
      expect(repository.actions.length, 1);
      repository.mutating!.complete(const DataSuccess('Confirmed'));
      await pending;
      expect(bloc.state.appointments!.single.status, 'CONFIRMED');
      expect(repository.listCalls, 1);
    },
  );

  test('edit result merges locally and preserves other appointments', () async {
    await dispatch(bloc, const GetAllAppointmentsEvent(), [
      hasStatus(RemoteAppointmentStatus.loading),
      hasStatus(RemoteAppointmentStatus.loaded),
    ]);
    final updated = appointment.copyWith(meetAt: DateTime.utc(2030, 1, 3));
    final changed = bloc.stream.firstWhere(
      (state) => state.appointments?.single.meetAt == updated.meetAt,
    );
    bloc.add(AppointmentChangedEvent(appointment: updated));
    await changed;
    expect(bloc.state.appointments, [updated]);
    expect(repository.listCalls, 1);
  });

  test(
    'state copyWith retains data and clears transient feedback for the next request',
    () {
      final failure = DioException(requestOptions: RequestOptions());
      final previous = RemoteAppointmentState(
        appointments: [appointment],
        requestStatus: RemoteAppointmentStatus.failure,
        dio: failure,
        message: 'Old result',
      );
      final next = previous.copyWith(
        requestStatus: RemoteAppointmentStatus.submitting,
        clearResult: true,
      );
      expect(next.appointments, same(previous.appointments));
      expect(next.dio, isNull);
      expect(next.message, isNull);
      expect(next.isBusy, isTrue);
      expect(previous.dio, same(failure));
    },
  );
}
