

import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/profile/domain/entities/profile.dart';

abstract class ProfileRepository {
  Future<DataState<ProfileEntity>> getProfile();
  Future<DataState<ProfileEntity>> updateProfile(String? fullname, String? gender, String? description, String? avatar);
  Future<DataState<ProfileEntity>> createProfile(String fullname, String gender, String description, String avatar);
  Future<DataState<ImageEntity>> uploadAvatar(String filePath);
}