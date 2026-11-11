import 'dart:io';

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:roomio/core/constants/constants.dart';
import 'package:roomio/features/profile/data/models/profile.dart';

part 'profile_landlord_api_service.g.dart';

@RestApi(baseUrl: profileLandlordAPIBaseUrl)
abstract class ProfileLandlordApiService { 
  factory ProfileLandlordApiService(Dio dio, {String baseUrl}) = _ProfileLandlordApiService;

  @POST('/profile')
  Future<HttpResponse<ProfileResponseModel>> createProfile(
    @Body() ProfileRequestModel request,
  );
  @GET('/profile')
  Future<HttpResponse<ProfileResponseModel>> getProfile();

  @PATCH('/profile')
  Future<HttpResponse<ProfileResponseModel>> updateProfile(
    @Body() ProfileRequestModel request,
  );
  @MultiPart()
  @POST('/profile/upload-avatar')
  Future<HttpResponse<ImageResponseModel>> uploadAvatar(
    @Part(name: 'image') File image,
  );
}