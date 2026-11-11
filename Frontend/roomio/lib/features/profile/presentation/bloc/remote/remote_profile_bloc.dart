import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/profile/domain/entities/profile.dart';
import 'package:roomio/features/profile/domain/usecase/landlord/create_profile.dart';
import 'package:roomio/features/profile/domain/usecase/landlord/get_profile.dart';
import 'package:roomio/features/profile/domain/usecase/landlord/update_profile.dart';
import 'package:roomio/features/profile/domain/usecase/landlord/upload_avatar.dart';
import 'package:roomio/features/profile/domain/usecase/tenant/create_profile.dart';
import 'package:roomio/features/profile/domain/usecase/tenant/get_profile.dart';
import 'package:roomio/features/profile/domain/usecase/tenant/update_profile.dart';
import 'package:roomio/features/profile/domain/usecase/tenant/upload_avatar.dart';
import 'package:roomio/features/profile/presentation/bloc/remote/remote_profile_event.dart';
import 'package:roomio/features/profile/presentation/bloc/remote/remote_profile_state.dart';

class RemoteProfileBloc extends Bloc<RemoteProfileEvent, RemoteProfileState> {
  final String role ;
  final CreateProfileLandLordUseCase _createProfileLandLordUseCase ; 
  final GetProfileLandLordUseCase _getProfileLandLordUseCase ; 
  final UpdateProfileLandLordUseCase _updateProfileLandLordUseCase ; 
  final UploadAvatarLandLordUseCase _uploadAvatarLandLordUseCase ; 

  final CreateProfileTenantUseCase _createProfileTenantUseCase ;
  final GetProfileTenantUseCase _getProfileTenantUseCase ; 
  final UpdateProfileTenantUseCase _updateProfileTenantUseCase ; 
  final UploadAvatarTenantUseCase _uploadAvatarTenantUseCase ;

  RemoteProfileBloc(this.role , this._createProfileLandLordUseCase,this._updateProfileLandLordUseCase , this._getProfileLandLordUseCase,
  this._uploadAvatarLandLordUseCase,this._createProfileTenantUseCase,this._updateProfileTenantUseCase,
  this._getProfileTenantUseCase,this._uploadAvatarTenantUseCase ):super(const RemoteProfileInitial()){
    on<CreateProfileEvent>(createProfile);
    on<UpdateProfileEvent>(updateProfile);
    on<getProfileEvent>(getProfile);
    on<UploadAvatarEvent>(uploadAvatar);
  }

  void createProfile(CreateProfileEvent event, Emitter<RemoteProfileState> emit) async {
    emit(RemoteProfileLoading()) ; 
    if(role =='LANDLORD'){
      final dataState = await _createProfileLandLordUseCase(ProfileEntity(name : event.name , gender: event.gender,description: event.description,avartarUrl: event.avatarUrl)) ; 
      if (dataState is DataSuccess) {
      emit(RemoteProfileSuccessState( profile:dataState.data! ));
      } else {
        emit(RemoteProfileFailure(dio: dataState.error!));
      }
    }
    else{
      final dataState = await _createProfileTenantUseCase(ProfileEntity(name : event.name , gender: event.gender,description: event.description,avartarUrl: event.avatarUrl)) ; 
      if (dataState is DataSuccess) {
      emit(RemoteProfileSuccessState( profile:dataState.data! ));
      } else {
        emit(RemoteProfileFailure(dio: dataState.error!));
      }
    }

  }
  void updateProfile(UpdateProfileEvent event, Emitter<RemoteProfileState> emit) async {
    emit(RemoteProfileLoading()) ; 
    if(role =='LANDLORD'){
      final dataState = await _updateProfileLandLordUseCase(ProfileEntity(name : event.name , gender: event.gender,description: event.description,avartarUrl: event.avatarUrl)) ; 
      if (dataState is DataSuccess) {
      emit(RemoteProfileSuccessState( profile:dataState.data! ));
      } else {
        emit(RemoteProfileFailure(dio: dataState.error!));
      }
    }
    else{
      final dataState = await _updateProfileTenantUseCase(ProfileEntity(name : event.name , gender: event.gender,description: event.description,avartarUrl: event.avatarUrl)) ; 
      if (dataState is DataSuccess) {
      emit(RemoteProfileSuccessState( profile:dataState.data! ));
      } else {
        emit(RemoteProfileFailure(dio: dataState.error!));
      }
    }
  }
  void getProfile(getProfileEvent event, Emitter<RemoteProfileState> emit) async {
    emit(RemoteProfileLoading()) ; 
    if(role =='LANDLORD'){
      final dataState = await _getProfileLandLordUseCase(null) ; 
      if (dataState is DataSuccess) {
      emit(RemoteProfileSuccessState( profile:dataState.data! ));
      } else {
        emit(RemoteProfileFailure(dio: dataState.error!));
      }
    }
    else{
      final dataState = await _getProfileTenantUseCase(null)  ; 
      if (dataState is DataSuccess) {
      emit(RemoteProfileSuccessState( profile:dataState.data! ));
      } else {
        emit(RemoteProfileFailure(dio: dataState.error!));
      }
    }
  }
  void uploadAvatar(UploadAvatarEvent event, Emitter<RemoteProfileState> emit) async {
    emit(RemoteProfileLoading()) ; 
    if(role =='LANDLORD'){
      final dataState = await _uploadAvatarLandLordUseCase(event.avatarUrl) ; 
      if (dataState is DataSuccess) {
      emit(RemoteUploadAvatarSuccess(image: dataState.data! ));
      } else {
        emit(RemoteProfileFailure(dio: dataState.error!));
      }
    }
    else{
      final dataState = await _uploadAvatarTenantUseCase(event.avatarUrl) ; 
      if (dataState is DataSuccess) {
      emit(RemoteUploadAvatarSuccess(image: dataState.data! ));
      } else {
        emit(RemoteProfileFailure(dio: dataState.error!));
      }
    }
  }

}