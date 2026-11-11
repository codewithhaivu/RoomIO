


import 'package:roomio/features/profile/domain/entities/profile.dart';

class ProfileRequestModel extends ProfileEntity {
  const ProfileRequestModel({
    super.name,
    super.gender,
    super.avartarUrl,
    super.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'fullName': name,
      'gender': gender,
      'avatar': avartarUrl,
      'description': description
    };
  }
}

class ProfileResponseModel extends ProfileEntity {
  const ProfileResponseModel({
    super.name,
    super.gender,
    super.avartarUrl,
    super.description,
    super.isverified,
    super.message
  });

  factory ProfileResponseModel.fromJson(Map<String, dynamic> json) {
    return ProfileResponseModel(
      name: json['fullName'] as String?,
      gender: json['gender'] as String?,
      avartarUrl: json['avatar'] as String?,
      description: json['description'] as String?,
      isverified: json['is_verify'] as bool?,
      message: json['message'] as String?,
    );
  }
}

class ImageResponseModel extends ImageEntity {
  const ImageResponseModel({
    super.imageUrl,
    super.publicId,
  });

  factory ImageResponseModel.fromJson(Map<String, dynamic> json) {
    return ImageResponseModel(
      imageUrl: json['image_url'] as String?,
      publicId: json['public_id'] as String?,
    );
  }
}