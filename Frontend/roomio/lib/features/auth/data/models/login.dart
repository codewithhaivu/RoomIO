import 'package:roomio/features/auth/domain/entities/login.dart';

class LoginResponseModel extends LoginResponseEntity {
  const LoginResponseModel({
    required super.accessToken,
    required super.rfToken,
    required super.role,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    return LoginResponseModel(
      accessToken: json['access_token'],
      rfToken: json['refresh_token'],
      role: json['role'],
    );
  }
}

class LoginRequestModel extends LoginRequestEntity {
  const LoginRequestModel({
    required super.phoneNumber,
    required super.password,
  });
  Map<String, dynamic> toJson() {
    return {
      'phone_number': phoneNumber,
      'password': password,
    };
  }
}