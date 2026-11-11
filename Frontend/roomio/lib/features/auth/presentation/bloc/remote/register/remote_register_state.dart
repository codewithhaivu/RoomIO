import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
// Nhớ import thêm class Entity của bạn nếu cần

abstract class RemoteRegisterState extends Equatable {
  const RemoteRegisterState();
  
  @override
  List<Object?> get props => [];
}

class RemoteRegisterInitial extends RemoteRegisterState {
  const RemoteRegisterInitial();
}

class RemoteRegisterLoading extends RemoteRegisterState {
  const RemoteRegisterLoading();
}


class SendOTPSuccessState extends RemoteRegisterState {
  final String? otp; 
  
  const SendOTPSuccessState({required this.otp});

  @override
  List<Object?> get props => [otp];
}

class VerifyOTPSuccessState extends RemoteRegisterState {
  final bool? isVerified; 
  
  const VerifyOTPSuccessState({required this.isVerified});

  @override
  List<Object?> get props => [isVerified];
}

class RemoteRegisterSuccessState extends RemoteRegisterState {
  final String? message; 
  
  const RemoteRegisterSuccessState({required this.message});

  @override
  List<Object?> get props => [message];
}

// Dùng chung một trạng thái báo lỗi cho cả 3 tác vụ
class RemoteRegisterFailure extends RemoteRegisterState {
  final DioException? dioException;
  
  const RemoteRegisterFailure({required this.dioException});

  @override
  List<Object?> get props => [dioException];
}