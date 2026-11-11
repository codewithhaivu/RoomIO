import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:roomio/core/constants/constants.dart';
import 'package:roomio/features/auth/data/models/check_phone.dart';
import 'package:roomio/features/auth/data/models/login.dart';
import 'package:roomio/features/auth/data/models/register.dart';  

part 'account_api_service.g.dart';

@RestApi(baseUrl: authAPIBaseUrl)
abstract class AccountApiService {
  factory AccountApiService(Dio dio, {String baseUrl}) = _AccountApiService;

  @POST('/check-phone')
  Future<HttpResponse<CheckPhoneResponseModel>> checkPhoneExists(
    @Body() CheckPhoneRequestModel request,
  );

  @POST('/login')
  Future<HttpResponse<LoginResponseModel>> login(
    @Body() LoginRequestModel request,
  );

  @POST('/register')
  Future<HttpResponse<RegisterResponseModel>> register(
    @Body() RegisterRequestModel request,
  );

  @POST('/register/verify-otp')
  Future<HttpResponse<VerifyOTPResponseModel>> verifyOTP(
    @Body() VerifyOTPRequestModel request,
  );

  @POST('/register/send-otp')
  Future<HttpResponse<SendOTPResponseModel>> sendOTP(
    @Body() SendOTPRequestModel request,
  );
  @POST('/forgot-password/send-otp')
  Future<HttpResponse<SendOTPResponseModel>> sendForgotPasswordOTP(
    @Body() SendOTPRequestModel request,
  );
  @POST('/forgot-password/verify-otp')
  Future<HttpResponse<VerifyOTPResponseModel>> verifyForgotPasswordOTP(
    @Body() VerifyOTPRequestModel request,
  );
  @PATCH('/forgot-password/reset')
  Future<HttpResponse<ResetPasswordResponseModel>> resetPassword(
    @Body() ResetPasswordRequestModel request,
  );
  @POST('/refresh-token')
  Future<HttpResponse<RefreshTokenResponseModel>> refreshToken(
    @Body() RefreshTokenRequestModel request,
  );
  @POST('/logout')
  Future<HttpResponse<LogoutResponseModel>> logout(
    @Body() LogoutRequestModel request,
  );
}