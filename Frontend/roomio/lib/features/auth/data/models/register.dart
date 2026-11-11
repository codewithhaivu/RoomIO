import 'package:roomio/features/auth/domain/entities/register.dart';

class RegisterRequestModel extends RegisterRequestEntity {
  const RegisterRequestModel({
    required super.phoneNumber,
    required super.password,
    required super.role,
  });

  Map<String, dynamic> toJson() {
    return {
      'phone_number': phoneNumber,
      'password': password,
      'role': role,
    };
  }
}

class VerifyOTPRequestModel extends VerifyOTPRequestEntity {
  const VerifyOTPRequestModel({
    required super.phoneNumber,
    required super.otp,
  });

  Map<String, dynamic> toJson() {
    return {
      'phone_number': phoneNumber,
      'OTP': otp,
    };
  }
}

class RegisterResponseModel {
  final String message;

  const RegisterResponseModel({required this.message});

  factory RegisterResponseModel.fromJson(Map<String, dynamic> json) {
    return RegisterResponseModel(
      message: json['message'] ?? '',
    );
  }
}


class VerifyOTPResponseModel {
  final bool isVerified;

  const VerifyOTPResponseModel({required this.isVerified});

  factory VerifyOTPResponseModel.fromJson(Map<String, dynamic> json) {
    return VerifyOTPResponseModel(
      isVerified: json['is_verified'] ?? false,
    );
  }
}

class SendOTPRequestModel {
  final String phoneNumber;

  const SendOTPRequestModel({required this.phoneNumber});

  Map<String, dynamic> toJson() {
    return {
      'phone_number': phoneNumber,
    };
  }
}

class SendOTPResponseModel {
  final String message;

  const SendOTPResponseModel({required this.message});

  factory SendOTPResponseModel.fromJson(Map<String, dynamic> json) {
    return SendOTPResponseModel(
      message: json['message'] ?? '',
    );
  }
}

class ResetPasswordRequestModel {
  final String phoneNumber;
  final String newPassword;

  const ResetPasswordRequestModel({
    required this.phoneNumber,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() {
    return {
      'phone_number': phoneNumber,
      'new_password': newPassword,
    };
  }
}

class ResetPasswordResponseModel {
  final String message;

  const ResetPasswordResponseModel({required this.message});

  factory ResetPasswordResponseModel.fromJson(Map<String, dynamic> json) {
    return ResetPasswordResponseModel(
      message: json['message'] ?? '',
    );
  }
}

class RefreshTokenRequestModel {
  final String refreshToken;

  const RefreshTokenRequestModel({required this.refreshToken});

  Map<String, dynamic> toJson() {
    return {
      'refresh_token': refreshToken,
    };
  }
}

class RefreshTokenResponseModel {
  final String accessToken;

  const RefreshTokenResponseModel({
    required this.accessToken
  });

  factory RefreshTokenResponseModel.fromJson(Map<String, dynamic> json) {
    return RefreshTokenResponseModel(
      accessToken: json['access_token'] ?? ''
    );
  }
}

class LogoutRequestModel {
  final String refreshToken;

  const LogoutRequestModel({required this.refreshToken});

  Map<String, dynamic> toJson() {
    return {
      'refresh_token': refreshToken,
    };
  }
}

class LogoutResponseModel {
  final String message;

  const LogoutResponseModel({required this.message});

  factory LogoutResponseModel.fromJson(Map<String, dynamic> json) {
    return LogoutResponseModel(
      message: json['message'] ?? '',
    );
  }
}