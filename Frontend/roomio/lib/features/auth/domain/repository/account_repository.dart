

import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/auth/domain/entities/login.dart';
abstract class AccountRepository {
  Future<DataState<bool>> checkPhoneExists(String phoneNumber);
  Future<DataState<LoginResponseEntity>> login(String phoneNumber, String password);
  Future<DataState<String>> register(String phoneNumber, String password, String role);
  Future<DataState<bool>> verifyOTP(String phoneNumber, String otp);
  Future<DataState<String>> sendOTP(String phoneNumber);
  Future<DataState<String>> sendForgotPasswordOTP(String phoneNumber);
  Future<DataState<bool>> verifyForgotPasswordOTP(String phoneNumber, String otp);
  Future<DataState<String>> resetPassword(String phoneNumber, String newPassword);
  Future<DataState<String>> refreshToken(String refreshToken);
  Future<DataState<String>> logout(String refreshToken);
}