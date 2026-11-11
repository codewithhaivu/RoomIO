import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:roomio/features/profile/domain/entities/profile.dart';

abstract class RemoteProfileState extends Equatable {
  const RemoteProfileState();
  
  @override
  List<Object?> get props => [];
}

class RemoteProfileInitial extends RemoteProfileState {
  const RemoteProfileInitial();
}
class RemoteProfileLoading extends RemoteProfileState {
  const RemoteProfileLoading();
}

class RemoteProfileSuccessState extends RemoteProfileState {
  final ProfileEntity profile ; 
  
  const RemoteProfileSuccessState({ required this.profile});

  @override
  List<Object?> get props => [ profile];
}
class RemoteUploadAvatarSuccess extends RemoteProfileState{
  final ImageEntity image ; 
  const RemoteUploadAvatarSuccess({required this.image}) ; 
}
class RemoteProfileFailure extends RemoteProfileState {
  final DioException dio ;
  
  const RemoteProfileFailure({required this.dio});

  @override
  List<Object?> get props => [dio];
}
