import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

abstract class RemoteAppAuthState extends Equatable {
  const RemoteAppAuthState();
  @override
  List<Object> get props => [];

}
class RemoteAppAuthInitial extends RemoteAppAuthState {
  const RemoteAppAuthInitial();
}

class RemoteAppAuthLoading extends RemoteAppAuthState {
  const RemoteAppAuthLoading();
}

class AppAuthenticated extends RemoteAppAuthState {
  const AppAuthenticated();
}

class AppUnauthenticated extends RemoteAppAuthState {
  const AppUnauthenticated();
}
class GetTokenSuccessState extends RemoteAppAuthState {
  final String token;
  const GetTokenSuccessState({required this.token});
  @override
  List<Object> get props => [token];
}
class LogoutSuccessState extends RemoteAppAuthState {
  final String message;
  const LogoutSuccessState({required this.message});
  @override
  List<Object> get props => [message];
}
class RemoteAppAuthErrorState extends RemoteAppAuthState {
  final DioException error;
  const RemoteAppAuthErrorState({required this.error});
  @override
  List<Object> get props => [error];
}