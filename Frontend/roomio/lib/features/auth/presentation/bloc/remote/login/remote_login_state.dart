import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:roomio/features/auth/domain/entities/login.dart';

abstract class RemoteLoginState extends Equatable {
  final LoginResponseEntity? loginResponseEntity; 
  final DioException? dioException;
  
  const RemoteLoginState({this.loginResponseEntity, this.dioException});
  @override
  List<Object?> get props => [loginResponseEntity, dioException];

}
class RemoteLoginInitial extends RemoteLoginState {
  const RemoteLoginInitial();
}

class RemoteLoginLoading extends RemoteLoginState {
  const RemoteLoginLoading();
}
class RemoteLoginSuccess extends RemoteLoginState {
  const RemoteLoginSuccess({required LoginResponseEntity loginResponseEntity}) : super(loginResponseEntity: loginResponseEntity);
}
class RemoteLoginFailure extends RemoteLoginState {
  const RemoteLoginFailure({required DioException dioException}) : super(dioException: dioException);
}

class CheckPhoneNumberSuccessState extends RemoteLoginState {
  final bool isExist;
  const CheckPhoneNumberSuccessState({required this.isExist});
  @override
  List<Object> get props => [isExist];
}