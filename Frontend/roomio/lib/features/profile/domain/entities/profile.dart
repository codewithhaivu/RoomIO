import 'package:equatable/equatable.dart';

class ProfileEntity extends Equatable {
  final String? name;
  final String? gender;
  final String? avartarUrl;
  final String? description;
  final bool? isverified;
  final String?  message ; 

  const ProfileEntity({
    this.name,
    this.gender,
    this.avartarUrl,
    this.description,
    this.isverified,
    this.message,
  });

  @override
  List<Object?> get props => [
    name,
    gender,
    avartarUrl,
    description,
    isverified,
    message
  ];
}

class ImageEntity extends Equatable {
  final String? imageUrl;
  final String? publicId;

  const ImageEntity({
    this.imageUrl,
    this.publicId,
  });

  @override
  List<Object?> get props => [
    imageUrl,
    publicId
  ];
}