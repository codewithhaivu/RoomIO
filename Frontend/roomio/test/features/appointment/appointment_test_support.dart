import 'dart:async';
import 'package:dio/dio.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/appointment/data/data_sources/remote/appointment_api_service.dart';
import 'package:roomio/features/appointment/data/models/appointment.dart';
import 'package:roomio/features/appointment/data/repository/appointment_repository_impl.dart';
import 'package:roomio/features/appointment/domain/entities/appointment.dart';
import 'package:roomio/features/appointment/domain/repository/appointment_repository.dart';
import 'package:roomio/features/appointment/domain/usecases/confirm_appointment.dart';
import 'package:roomio/features/appointment/domain/usecases/destroy_appointment.dart';
import 'package:roomio/features/appointment/domain/usecases/get_all_appointments.dart';
import 'package:roomio/features/appointment/domain/usecases/send_appointment.dart';
import 'package:roomio/features/appointment/domain/usecases/update_appointment.dart';
import 'package:roomio/features/appointment/presentation/bloc/remote/remote_appointment_bloc.dart';

Map<String, dynamic> get appointmentJson => {
  'id_appointment': 'appointment-id',
  'id_room': 'room-id',
  'name_room': 'Phòng gần trường đại học',
  'name_tenant': 'Nguyễn Văn An',
  'meet_at': '2030-01-02T09:30:00',
  'status': 'PENDING',
};
AppointmentEntityResponse get appointment =>
    AppointmentModelResponse.fromJson(appointmentJson);
AppointmentEntityRequest get appointmentRequest => AppointmentEntityRequest(
  idRoom: 'room-id',
  meetAt: DateTime.utc(2030, 1, 2, 2, 30),
);

RemoteAppointmentBloc appointmentBloc(AppointmentRepository repository) =>
    RemoteAppointmentBloc(
      SendAppointmentUseCase(repository),
      GetAllAppointmentsUseCase(repository),
      ConfirmAppointmentUseCase(repository),
      DestroyAppointmentUseCase(repository),
      UpdateAppointmentUseCase(repository),
    );

class AppointmentTestApi {
  late final Dio dio;
  late final AppointmentRepositoryImpl repository;
  final List<RequestOptions> requests = [];
  Object? responseData;
  int statusCode = 200;
  DioException? error;
  Object? Function(RequestOptions)? responseFor;

  AppointmentTestApi() {
    dio = Dio(BaseOptions(validateStatus: (_) => true));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          if (error != null) {
            handler.reject(error!);
            return;
          }
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: statusCode,
              data: responseFor == null ? responseData : responseFor!(options),
            ),
          );
        },
      ),
    );
    repository = AppointmentRepositoryImpl(AppointmentApiService(dio));
  }
  void dispose() => dio.close(force: true);
}

class FakeAppointmentRepository implements AppointmentRepository {
  List<AppointmentEntityResponse> appointments = [appointment];
  DioException? error;
  int listCalls = 0;
  int sendCalls = 0;
  final List<String> actions = [];
  AppointmentEntityRequest? request;
  Completer<DataState<AppointmentEntityResponse>>? sending;
  Completer<DataState<String>>? mutating;
  final List<Completer<DataState<List<AppointmentEntityResponse>>>> loads = [];

  DataState<T> result<T>(T value) =>
      error == null ? DataSuccess(value) : DataError(error!);
  @override
  Future<DataState<List<AppointmentEntityResponse>>>
  getAllAppointments() async {
    final index = listCalls++;
    return index < loads.length
        ? await loads[index].future
        : result(appointments);
  }

  @override
  Future<DataState<AppointmentEntityResponse>> sendAppointment(
    AppointmentEntityRequest request,
  ) async {
    sendCalls++;
    this.request = request;
    return sending == null ? result(appointment) : await sending!.future;
  }

  @override
  Future<DataState<String>> confirmAppointment(
    String idAppointment,
    String status,
  ) async {
    actions.add('$idAppointment/$status');
    return mutating == null
        ? result('Đã cập nhật lịch hẹn')
        : await mutating!.future;
  }

  @override
  Future<DataState<String>> destroyAppointment(String idAppointment) async {
    actions.add('DELETE/$idAppointment');
    return mutating == null
        ? result('Đã hủy lịch hẹn')
        : await mutating!.future;
  }

  @override
  Future<DataState<String>> updateAppointment(
    String idAppointment,
    AppointmentEntityRequest request,
  ) async {
    actions.add('PATCH/$idAppointment');
    this.request = request;
    return result('Đã đổi lịch hẹn');
  }
}
