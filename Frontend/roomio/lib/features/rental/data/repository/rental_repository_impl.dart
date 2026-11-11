import 'dart:io';
import 'package:dio/dio.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/rental/data/data_sources/remote/rental_api_service.dart';
import 'package:roomio/features/rental/data/models/rental.dart';
import 'package:roomio/features/rental/domain/entities/rental.dart';
import 'package:roomio/features/rental/domain/repository/rental_repository.dart';

class RentalRepositoryImpl implements RentalRepository {
  final RentalApiService _rentalApiService;
  RentalRepositoryImpl(this._rentalApiService);

  @override
  Future<DataState<RentalResponse>> createQRCode(String roomId) async {
    try {
      final httpResponse = await _rentalApiService.createQRCode(roomId);
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
  Future<DataState<RentalVerifyResponse>> verifyQRCode(
    RentalVerifyRequest request,
  ) async {
    try {
      final httpResponse = await _rentalApiService.verifyQRCode(
        RentalModelVerifyRequest.fromEntity(request),
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
  Future<DataState<String>> destroyRelation(String rentalRelationId) async {
    try {
      final httpResponse = await _rentalApiService.destroyRelation(
        rentalRelationId,
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
  Future<DataState<List<TenantRentalResponse>>> getMyTenants() async {
    try {
      final httpResponse = await _rentalApiService.getMyTenants();
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
  Future<DataState<List<RentalRoomResponse>>> getCurrentRentRoom() async {
    try {
      final httpResponse = await _rentalApiService.getCurrentRentRoom();
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
}
