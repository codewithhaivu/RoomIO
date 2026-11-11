import 'package:equatable/equatable.dart';

class LocationEntity extends Equatable {
  final String name;
  final double longitude;
  final double latitude;

  const LocationEntity({
    required this.name,
    required this.longitude,
    required this.latitude,
  });

  @override
  List<Object?> get props => [name, longitude, latitude];
}

class InteriorEntity extends Equatable {
  final String id; // UUID từ backend qua JSON sẽ là String
  final String name;

  const InteriorEntity({required this.id, required this.name});

  @override
  List<Object?> get props => [id, name];
}

class AmenityEntity extends Equatable {
  final String id;
  final String name;

  const AmenityEntity({required this.id, required this.name});

  @override
  List<Object?> get props => [id, name];
}

class RoomImageEntity extends Equatable {
  final String imageUrl;
  final String publicId;
  final bool isThumbnail;

  const RoomImageEntity({
    required this.imageUrl,
    required this.publicId,
    required this.isThumbnail,
  });

  @override
  List<Object?> get props => [imageUrl, publicId, isThumbnail];
}

class LandlordInfoEntity extends Equatable {
  final String? accountId;
  final String fullName;
  final String gender;
  final String? avatar;
  final bool isVerify;

  const LandlordInfoEntity({
    this.accountId,
    required this.fullName,
    required this.gender,
    this.avatar,
    required this.isVerify,
  });

  @override
  List<Object?> get props => [accountId, fullName, gender, avatar, isVerify];
}
