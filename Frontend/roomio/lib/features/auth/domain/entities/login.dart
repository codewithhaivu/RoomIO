import 'package:equatable/equatable.dart';

class LoginResponseEntity extends Equatable {
  final String accessToken;
  final String rfToken;
  final String role;

  const LoginResponseEntity({
    required this.accessToken,
    required this.rfToken,
    required this.role,
  });

  @override
  List<Object?> get props => [accessToken, rfToken, role];
}

class LoginRequestEntity extends Equatable {
  final String phoneNumber;
  final String password;

  const LoginRequestEntity({
    required this.phoneNumber,
    required this.password,
  });

  @override
  List<Object?> get props => [phoneNumber, password];
}

