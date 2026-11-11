import 'dart:io';
import 'package:dio/dio.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/auth/data/data_sources/remote/account_api_service.dart';
import 'package:roomio/features/auth/data/models/check_phone.dart';
import 'package:roomio/features/auth/data/models/login.dart';
import 'package:roomio/features/auth/data/models/register.dart';
import 'package:roomio/features/auth/domain/repository/account_repository.dart';

class AccountRepositoryImpl implements AccountRepository {
  final AccountApiService _accountApiService;
  AccountRepositoryImpl(this._accountApiService);

  @override
  Future<DataState<bool>> checkPhoneExists(String phoneNumber) async {
    try {
      final httpResponse = await _accountApiService.checkPhoneExists(
        CheckPhoneRequestModel(phoneNumber: phoneNumber),
      );

      if (httpResponse.response.statusCode == HttpStatus.ok) {
        return DataSuccess(httpResponse.data.exists);
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
  Future<DataState<LoginResponseModel>> login(String phoneNumber, String password) async {
    try {
      final httpResponse = await _accountApiService.login(
        LoginRequestModel(phoneNumber: phoneNumber, password: password),
      );

      if (httpResponse.response.statusCode == HttpStatus.ok) {
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
  Future<DataState<String>> register(String phoneNumber, String password, String role) async {
    try {
      final httpResponse = await _accountApiService.register(
        RegisterRequestModel(phoneNumber: phoneNumber, password: password, role: role),
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
  Future<DataState<bool>> verifyOTP(String phoneNumber, String otp) async  {
    try {
      final httpResponse = await _accountApiService.verifyOTP(
        VerifyOTPRequestModel(phoneNumber: phoneNumber, otp: otp),
      );

      if (httpResponse.response.statusCode == HttpStatus.ok) {
        return DataSuccess(httpResponse.data.isVerified);
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
  Future<DataState<String>> logout(String refreshToken) async {
    try {
      final httpResponse = await _accountApiService.logout(
        LogoutRequestModel(refreshToken: refreshToken),
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
  Future<DataState<String>> refreshToken(String refreshToken) async {
    try {
      final httpResponse = await _accountApiService.refreshToken(
        RefreshTokenRequestModel(refreshToken: refreshToken),
      );

      if (httpResponse.response.statusCode == HttpStatus.ok) {
        return DataSuccess(httpResponse.data.accessToken);
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
  Future<DataState<String>> resetPassword(String phoneNumber, String newPassword) async {
    try {
      final httpResponse = await _accountApiService.resetPassword(
        ResetPasswordRequestModel(phoneNumber: phoneNumber, newPassword: newPassword),
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
  Future<DataState<String>> sendForgotPasswordOTP(String phoneNumber) async {
    try {
      final httpResponse = await _accountApiService.sendForgotPasswordOTP(
        SendOTPRequestModel(phoneNumber: phoneNumber),
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
  Future<DataState<String>> sendOTP(String phoneNumber) async  {
    try {
      final httpResponse = await _accountApiService.sendOTP(
        SendOTPRequestModel(phoneNumber: phoneNumber),
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
  Future<DataState<bool>> verifyForgotPasswordOTP(String phoneNumber, String otp) async  {
    try {
      final httpResponse = await _accountApiService.verifyForgotPasswordOTP(
        VerifyOTPRequestModel(phoneNumber: phoneNumber, otp: otp),
      );

      if (httpResponse.response.statusCode == HttpStatus.ok) {
        return DataSuccess(httpResponse.data.isVerified);
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
