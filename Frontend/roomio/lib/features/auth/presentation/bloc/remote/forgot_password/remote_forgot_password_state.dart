import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

abstract class RemoteForgotPasswordState extends Equatable {
  const RemoteForgotPasswordState();
  
  @override
  List<Object?> get props => [];
}
class RemoteForgotPasswordInitial extends RemoteForgotPasswordState {
  const RemoteForgotPasswordInitial();
}
class RemoteForgotPasswordLoading extends RemoteForgotPasswordState {
  const RemoteForgotPasswordLoading();
}
// ignore: camel_case_types
class sendOTPForgotPasswordSuccessState extends RemoteForgotPasswordState {
  final String? otp; 
  
  const sendOTPForgotPasswordSuccessState({required this.otp});

  @override
  List<Object?> get props => [otp];
}

// ignore: camel_case_types
class verifyOTPForgotPasswordSuccessState extends RemoteForgotPasswordState {
  final bool? isVerified; 
  
  const verifyOTPForgotPasswordSuccessState({required this.isVerified});

  @override
  List<Object?> get props => [isVerified];
}

class ResetPasswordSuccessState extends RemoteForgotPasswordState {
  final String? message; 
  
  const ResetPasswordSuccessState({required this.message});

  @override
  List<Object?> get props => [message];
}

class RemoteForgotPasswordFailure extends RemoteForgotPasswordState {
  final DioException? dioException;
  
  const RemoteForgotPasswordFailure({required this.dioException});

  @override
  List<Object?> get props => [dioException];
}

