import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/appointment/data/models/appointment.dart';
import 'package:roomio/features/appointment/presentation/widgets/appointment_date_time.dart';
import 'appointment_test_support.dart';

void main() {
  late AppointmentTestApi api;
  setUp(() => api = AppointmentTestApi());
  tearDown(() => api.dispose());

  test(
    'status is mapped from JSON and defaults to PENDING for null or absent values',
    () {
      for (final status in ['PENDING', 'CONFIRMED', 'REJECTED']) {
        expect(
          AppointmentModelResponse.fromJson(
            appointmentJson..['status'] = status,
          ).status,
          status,
        );
      }
      expect(
        AppointmentModelResponse.fromJson(
          appointmentJson..['status'] = null,
        ).status,
        'PENDING',
      );
      expect(
        AppointmentModelResponse.fromJson(
          appointmentJson..remove('status'),
        ).status,
        'PENDING',
      );
    },
  );

  test(
    'entity copyWith changes status without mutating the original and participates in equality',
    () {
      final original = appointment;
      final updated = original.copyWith(status: 'CONFIRMED');
      expect(original.status, 'PENDING');
      expect(updated.status, 'CONFIRMED');
      expect(updated.idAppointment, original.idAppointment);
      expect(updated.meetAt, original.meetAt);
      expect(updated, isNot(original));
      expect(updated.copyWith(), updated);
    },
  );

  test(
    'JSON dates without timezone use Vietnam time; aware dates preserve the instant',
    () {
      for (final value in [
        '2030-01-02T09:30:00',
        '2030-01-02T09:30:00+07:00',
        '2030-01-02T02:30:00Z',
        '2030-01-01T21:30:00-05:00',
      ]) {
        final model = AppointmentModelResponse.fromJson(
          appointmentJson..['meet_at'] = value,
        );
        expect(model.meetAt, DateTime.utc(2030, 1, 2, 2, 30));
        expect(appointmentTime(model.meetAt), '09:30');
        expect(appointmentDate(model.meetAt), '02/01/2030');
      }
    },
  );

  test('request is JSON encodable and carries explicit UTC', () {
    final json = AppointmentModelRequest.fromEntity(
      appointmentRequest,
    ).toJson();
    expect(json['meet_at'], '2030-01-02T02:30:00.000Z');
    expect(jsonDecode(jsonEncode(json)), json);
    expect(
      appointmentInstant(DateTime(2030, 1, 2), 9, 30),
      appointmentRequest.meetAt,
    );
  });

  test('create accepts 201 and maps request/entity through Retrofit', () async {
    api.responseData = appointmentJson;
    api.statusCode = 201;
    final result = await api.repository.sendAppointment(appointmentRequest);
    expect(result, isA<DataSuccess>());
    expect(result.data, appointment);
    expect(api.requests.single.method, 'POST');
    expect(api.requests.single.uri.path, '/appointments/');
    expect(api.requests.single.data, {
      'id_room': 'room-id',
      'meet_at': '2030-01-02T02:30:00.000Z',
    });
  });

  test('list unwraps data and supports an empty response', () async {
    api.responseData = {
      'data': [appointmentJson],
    };
    expect((await api.repository.getAllAppointments()).data, [appointment]);
    api.responseData = {'data': []};
    expect((await api.repository.getAllAppointments()).data, isEmpty);
  });

  test('landlord confirmation extracts message from PATCH response', () async {
    api.responseData = {'message': 'Confirmed'};
    expect(
      (await api.repository.confirmAppointment(
        'appointment-id',
        'CONFIRMED',
      )).data,
      'Confirmed',
    );
    expect(api.requests.single.method, 'PATCH');
    expect(api.requests.single.path, '/appointment-id/CONFIRMED');
  });

  test('tenant cancellation uses DELETE and unwraps message', () async {
    api.responseData = {'message': 'Cancelled'};
    expect(
      (await api.repository.destroyAppointment('appointment-id')).data,
      'Cancelled',
    );
    expect(api.requests.single.method, 'DELETE');
    expect(api.requests.single.path, '/appointment-id');
  });

  test('rescheduling sends room id and aware time using PATCH', () async {
    api.responseData = {'message': 'Updated'};
    expect(
      (await api.repository.updateAppointment(
        'appointment-id',
        appointmentRequest,
      )).data,
      'Updated',
    );
    expect(api.requests.single.method, 'PATCH');
    expect(api.requests.single.path, '/appointment-id');
    expect(api.requests.single.data['id_room'], 'room-id');
    expect(
      DateTime.parse(api.requests.single.data['meet_at']),
      appointmentRequest.meetAt,
    );
  });

  for (final operation in ['create', 'list', 'confirm', 'destroy', 'update']) {
    Future<DataState<dynamic>> run() => switch (operation) {
      'create' => api.repository.sendAppointment(appointmentRequest),
      'list' => api.repository.getAllAppointments(),
      'confirm' => api.repository.confirmAppointment(
        'appointment-id',
        'REJECTED',
      ),
      'destroy' => api.repository.destroyAppointment('appointment-id'),
      _ => api.repository.updateAppointment(
        'appointment-id',
        appointmentRequest,
      ),
    };

    test('$operation retains DioException and server error details', () async {
      final options = RequestOptions(path: '/appointments/');
      api.error = DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: options,
          statusCode: 409,
          data: {'detail': 'Lịch hẹn bị trùng'},
        ),
      );
      final result = await run();
      expect(result, isA<DataError>());
      expect(result.error, same(api.error));
      expect(result.error!.response!.data['detail'], 'Lịch hẹn bị trùng');
    });

    test('$operation rejects an unexpected successful HTTP status', () async {
      api.statusCode = 202;
      api.responseData = switch (operation) {
        'create' => appointmentJson,
        'list' => {
          'data': [appointmentJson],
        },
        _ => {'message': 'Unexpected status'},
      };
      final result = await run();
      expect(result, isA<DataError>());
      expect(result.error!.type, DioExceptionType.badResponse);
      expect(result.error!.response!.statusCode, 202);
    });
  }
}
