import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/appointment/domain/entities/appointment.dart';

abstract class AppointmentRepository {
  Future<DataState<AppointmentEntityResponse>> sendAppointment(
    AppointmentEntityRequest request,
  );
  Future<DataState<List<AppointmentEntityResponse>>> getAllAppointments();
  Future<DataState<String>> confirmAppointment(
    String idAppointment,
    String status,
  );
  Future<DataState<String>> destroyAppointment(String idAppointment);
  Future<DataState<String>> updateAppointment(
    String idAppointment,
    AppointmentEntityRequest request,
  );
}
