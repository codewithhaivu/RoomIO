import 'package:equatable/equatable.dart';

class VerifyOTPRequestEntity extends Equatable {
  final String phoneNumber;
  final String otp;

  const VerifyOTPRequestEntity({
    required this.phoneNumber,
    required this.otp,
  });
  @override
  List<Object?> get props => [phoneNumber, otp];
}
class RegisterRequestEntity extends Equatable {
  final String phoneNumber;
  final String password;
  final String role ; 

  const RegisterRequestEntity({
    required this.phoneNumber,
    required this.password,
    required this.role,
  });
  @override
  List<Object?> get props => [phoneNumber, password, role];
}


class ResetPasswordRequestEntity extends Equatable {
  final String phoneNumber;
  final String newPassword;

  const ResetPasswordRequestEntity({
    required this.phoneNumber,
    required this.newPassword,
  });
  @override
  List<Object?> get props => [phoneNumber, newPassword];
}