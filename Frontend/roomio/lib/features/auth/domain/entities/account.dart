import 'package:equatable/equatable.dart';

class AccountEntity extends Equatable {
  final String phoneNumber;
  final String role ;
  final String state ;

  const AccountEntity({
    required this.phoneNumber,
    required this.role,
    required this.state,
  });

  @override
  List<Object?> get props => [phoneNumber, role, state];
}