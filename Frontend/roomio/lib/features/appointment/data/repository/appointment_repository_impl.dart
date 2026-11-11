import 'dart:io';
import 'package:dio/dio.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/appointment/data/data_sources/remote/appointment_api_service.dart';
import 'package:roomio/features/appointment/data/models/appointment.dart';
import 'package:roomio/features/appointment/domain/entities/appointment.dart';
import 'package:roomio/features/appointment/domain/repository/appointment_repository.dart';

class AppointmentRepositoryImpl implements AppointmentRepository {
  final AppointmentApiService _appointmentApiService;
  AppointmentRepositoryImpl(this._appointmentApiService);

  @override
  Future<DataState<AppointmentEntityResponse>> sendAppointment(
    AppointmentEntityRequest request,
  ) async {
    try {
      final httpResponse = await _appointmentApiService.sendAppointment(
        AppointmentModelRequest.fromEntity(request),
      );
      if (httpResponse.response.statusCode == HttpStatus.ok ||
          httpResponse.response.statusCode == HttpStatus.created) {
        return DataSuccess(httpResponse.data);
      } else {
        return DataError(
          DioException(
            error: httpResponse.response.statusMessage,
            response: httpResponse.response,
            type: DioExceptionType.badResponse,
            requestOptions: httpResponse.response.requestOptions,
          ),
        );
      }
    } on DioException catch (e) {
      return DataError(e);
    }
  }

  @override
  Future<DataState<List<AppointmentEntityResponse>>>
  getAllAppointments() async {
    try {
      final httpResponse = await _appointmentApiService.getAllAppointment();
      if (httpResponse.response.statusCode == HttpStatus.ok) {
        return DataSuccess(httpResponse.data.data);
      } else {
        return DataError(
          DioException(
            error: httpResponse.response.statusMessage,
            response: httpResponse.response,
            type: DioExceptionType.badResponse,
            requestOptions: httpResponse.response.requestOptions,
          ),
        );
      }
    } on DioException catch (e) {
      return DataError(e);
    }
  }

  @override
  Future<DataState<String>> confirmAppointment(
    String idAppointment,
    String status,
  ) async {
    try {
      final httpResponse = await _appointmentApiService.confirmAppointment(
        idAppointment,
        status,
      );
      if (httpResponse.response.statusCode == HttpStatus.ok) {
        return DataSuccess(httpResponse.data.message);
      } else {
        return DataError(
          DioException(
            error: httpResponse.response.statusMessage,
            response: httpResponse.response,
            type: DioExceptionType.badResponse,
            requestOptions: httpResponse.response.requestOptions,
          ),
        );
      }
    } on DioException catch (e) {
      return DataError(e);
    }
  }

  @override
  Future<DataState<String>> destroyAppointment(String idAppointment) async {
    try {
      final httpResponse = await _appointmentApiService.destroyAppointment(
        idAppointment,
      );
      if (httpResponse.response.statusCode == HttpStatus.ok) {
        return DataSuccess(httpResponse.data.message);
      } else {
        return DataError(
          DioException(
            error: httpResponse.response.statusMessage,
            response: httpResponse.response,
            type: DioExceptionType.badResponse,
            requestOptions: httpResponse.response.requestOptions,
          ),
        );
      }
    } on DioException catch (e) {
      return DataError(e);
    }
  }

  @override
  Future<DataState<String>> updateAppointment(
    String idAppointment,
    AppointmentEntityRequest request,
  ) async {
    try {
      final httpResponse = await _appointmentApiService.updateAppointment(
        idAppointment,
        AppointmentModelRequest.fromEntity(request),
      );
      if (httpResponse.response.statusCode == HttpStatus.ok) {
        return DataSuccess(httpResponse.data.message);
      } else {
        return DataError(
          DioException(
            error: httpResponse.response.statusMessage,
            response: httpResponse.response,
            type: DioExceptionType.badResponse,
            requestOptions: httpResponse.response.requestOptions,
          ),
        );
      }
    } on DioException catch (e) {
      return DataError(e);
    }
  }
}
