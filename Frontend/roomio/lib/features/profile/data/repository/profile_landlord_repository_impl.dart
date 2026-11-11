import 'dart:io';
import 'package:dio/dio.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/profile/data/data_sources/remote/profile_landlord_api_service.dart';
import 'package:roomio/features/profile/data/models/profile.dart';
import 'package:roomio/features/profile/domain/repository/profile_repository.dart';

class ProfileLandlordRepositoryImpl implements ProfileRepository {


  final ProfileLandlordApiService _profileApiService;
  ProfileLandlordRepositoryImpl(this._profileApiService);

  @override
  Future<DataState<ProfileResponseModel>> getProfile() async {
    try{
      final httpResponse = await  _profileApiService.getProfile();

      if (httpResponse.response.statusCode == HttpStatus.ok) {
        return DataSuccess(httpResponse.data);
      } else {
        return DataError(
          DioException(
            error: httpResponse.response.statusMessage,
            response: httpResponse.response,
            type: DioExceptionType.badResponse,
            requestOptions: httpResponse.response.requestOptions,
          ),
        );
      }
    } on DioException catch (e) {
      return DataError(e);
    }
  }


  @override
  Future<DataState<ImageResponseModel>> uploadAvatar(String filePath) async {
    try {
      final imageFile = File(filePath);
      final httpResponse = await _profileApiService.uploadAvatar(imageFile);

      if (httpResponse.response.statusCode == HttpStatus.ok) {
        return DataSuccess(httpResponse.data);
      } else {
        return DataError(
          DioException(
            error: httpResponse.response.statusMessage,
            response: httpResponse.response,
            type: DioExceptionType.badResponse,
            requestOptions: httpResponse.response.requestOptions,
          ),
        );
      }
    } on DioException catch (e) {
      return DataError(e);
    }
  }

  @override
  Future<DataState<ProfileResponseModel>> createProfile(String fullname, String gender, String description, String avatar) async  {
    try {
      final httpResponse = await _profileApiService.createProfile(ProfileRequestModel(
        name: fullname,
        gender: gender,
        description: description,
        avartarUrl: avatar,
      ));

      if (httpResponse.response.statusCode == HttpStatus.ok) {
        return DataSuccess(httpResponse.data);
      } else {
        return DataError(
          DioException(
            error: httpResponse.response.statusMessage,
            response: httpResponse.response,
            type: DioExceptionType.badResponse,
            requestOptions: httpResponse.response.requestOptions,
          ),
        );
      }
    } on DioException catch (e) {
      return DataError(e);
    }
  }

  @override
  Future<DataState<ProfileResponseModel>> updateProfile(String? fullname, String? gender, String? description, String? avatar) async {
    try {
      final httpResponse = await _profileApiService.updateProfile(ProfileRequestModel(
        name: fullname,
        gender: gender,
        description: description,
        avartarUrl: avatar,
      ));

      if (httpResponse.response.statusCode == HttpStatus.ok) {
        return DataSuccess(httpResponse.data);
      } else {
        return DataError(
          DioException(
            error: httpResponse.response.statusMessage,
            response: httpResponse.response,
            type: DioExceptionType.badResponse,
            requestOptions: httpResponse.response.requestOptions,
          ),
        );
      }
    } on DioException catch (e) {
      return DataError(e);
    }
  }

}