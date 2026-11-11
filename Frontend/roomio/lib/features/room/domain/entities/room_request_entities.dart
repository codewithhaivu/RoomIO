import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:roomio/features/room/domain/entities/room_sub_entities.dart';

class PostRoomRequestEntity extends Equatable {
  final String name;
  final double area;
  final double waterFee;
  final double serviceFee;
  final double parkingFee;
  final double rentalPrice;
  final double electricityFee;
  final String status;
  final String roomType;
  final LocationEntity location;
  final List<String> interiors;
  final List<String> amenities;
  final List<RoomImageEntity> images;

  const PostRoomRequestEntity({
    required this.name,
    required this.area,
    required this.waterFee,
    required this.serviceFee,
    required this.parkingFee,
    required this.rentalPrice,
    required this.electricityFee,
    required this.status,
    required this.roomType,
    required this.location,
    required this.interiors,
    required this.amenities,
    required this.images,
  });

  @override
  List<Object?> get props => [
    name,
    area,
    waterFee,
    serviceFee,
    parkingFee,
    rentalPrice,
    electricityFee,
    status,
    roomType,
    location,
    interiors,
    amenities,
    images,
  ];
}

class UpdateRoomRequestEntity extends Equatable {
  final String roomId;
  final String? name;
  final double? area;
  final double? waterFee;
  final double? serviceFee;
  final double? parkingFee;
  final double? rentalPrice;
  final double? electricityFee;
  final String? status;
  final String? roomType;
  final LocationEntity? location;
  final List<String>? interiors;
  final List<String>? amenities;
  final List<RoomImageEntity>? images;

  const UpdateRoomRequestEntity({
    required this.roomId,
    this.name,
    this.area,
    this.waterFee,
    this.serviceFee,
    this.parkingFee,
    this.rentalPrice,
    this.electricityFee,
    this.status,
    this.roomType,
    this.location,
    this.interiors,
    this.amenities,
    this.images,
  });

  @override
  List<Object?> get props => [
    roomId,
    name,
    area,
    waterFee,
    serviceFee,
    parkingFee,
    rentalPrice,
    electricityFee,
    status,
    roomType,
    location,
    interiors,
    amenities,
    images,
  ];
}

class UploadRoomImagesRequestEntity extends Equatable {
  final List<File> images;
  final List<bool> isThumbnails;

  const UploadRoomImagesRequestEntity({
    required this.images,
    required this.isThumbnails,
  });

  @override
  List<Object?> get props => [images, isThumbnails];
}

class UpdateRoomStatusRequestEntity extends Equatable {
  final String roomId;
  final String status;

  const UpdateRoomStatusRequestEntity({
    required this.roomId,
    required this.status,
  });

  @override
  List<Object?> get props => [roomId, status];
}

class SearchRoomByPositionRequestEntity extends Equatable {
  final double latitude;
  final double longitude;
  final double radius;

  const SearchRoomByPositionRequestEntity({
    required this.latitude,
    required this.longitude,
    required this.radius,
  });

  @override
  List<Object?> get props => [latitude, longitude, radius];
}

class SearchRoomsByAreaRequestEntity extends Equatable {
  final String locationId;
  final String district;
  final double radius;

  const SearchRoomsByAreaRequestEntity({
    required this.locationId,
    required this.district,
    this.radius = 10,
  });

  @override
  List<Object?> get props => [locationId, district, radius];
}
