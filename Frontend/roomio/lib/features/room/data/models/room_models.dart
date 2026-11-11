import 'package:roomio/features/room/data/models/nearby_room_models.dart';
import 'package:roomio/features/room/domain/entities/room_entities.dart';
import 'room_sub_models.dart';

class RoomModel extends RoomEntity {
  const RoomModel({
    required super.id,
    required super.name,
    required super.area,
    required super.waterFee,
    required super.serviceFee,
    required super.parkingFee,
    required super.rentalPrice,
    required super.electricityFee,
    required super.status,
    required super.roomType,
    required super.location,
    required super.interiors,
    required super.amenities,
    required super.images,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    // Bóc tách lớp lồng nhau: json['image']['response'] từ FastAPI
    final imageWrapper = json['image'] as Map<String, dynamic>?;
    final rawImages = imageWrapper?['response'] as List<dynamic>? ?? [];

    return RoomModel(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      area: (json['area'] as num).toDouble(),
      waterFee: (json['water_fee'] as num).toDouble(),
      serviceFee: (json['service_fee'] as num).toDouble(),
      parkingFee: (json['parking_fee'] as num).toDouble(),
      rentalPrice: (json['rental_price'] as num).toDouble(),
      electricityFee: (json['electricity_fee'] as num).toDouble(),
      status: json['status'] ?? '',
      roomType: json['room_type'] ?? '',
      location: LocationModel.fromJson(json['location']),
      interiors: (json['interiors'] as List<dynamic>? ?? [])
          .map((e) => InteriorModel.fromJson(e))
          .toList(),
      amenities: (json['amenities'] as List<dynamic>? ?? [])
          .map((e) => AmenityModel.fromJson(e))
          .toList(),
      images: rawImages.map((e) => RoomImageModel.fromJson(e)).toList(),
    );
  }
}

class PostRoomRequestModel {
  final String name;
  final double area;
  final double waterFee;
  final double serviceFee;
  final double parkingFee;
  final double rentalPrice;
  final double electricityFee;
  final String status;
  final String roomType;
  final LocationModel location;
  final List<String> interiors;
  final List<String> amenities;
  final List<RoomImageModel> images;
  const PostRoomRequestModel({
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
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'area': area,
      "water_fee": waterFee,
      "service_fee": serviceFee,
      "parking_fee": parkingFee,
      "rental_price": rentalPrice,
      "electricity_fee": electricityFee,
      "status": status,
      "room_type": roomType,
      "location": location.toJson(),
      "interiors": interiors,
      "amenities": amenities,
      "images": images.map((e) => e.toJson()).toList(),
    };
  }
}

class UpdateRoomRequestModel {
  final String? name;
  final double? area;
  final double? waterFee;
  final double? serviceFee;
  final double? parkingFee;
  final double? rentalPrice;
  final double? electricityFee;
  final String? status;
  final String? roomType;
  final LocationModel? location;
  final List<String>? interiors;
  final List<String>? amenities;
  final List<RoomImageModel>? images;

  const UpdateRoomRequestModel({
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

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (area != null) 'area': area,
      if (waterFee != null) 'water_fee': waterFee,
      if (serviceFee != null) 'service_fee': serviceFee,
      if (parkingFee != null) 'parking_fee': parkingFee,
      if (rentalPrice != null) 'rental_price': rentalPrice,
      if (electricityFee != null) 'electricity_fee': electricityFee,
      if (status != null) 'status': status,
      if (roomType != null) 'room_type': roomType,
      if (location != null) 'location': location!.toJson(),
      if (interiors != null) 'interiors': interiors,
      if (amenities != null) 'amenities': amenities,
      if (images != null) 'images': images!.map((e) => e.toJson()).toList(),
    };
  }
}

/// 1. Khớp với ListImageResponse ở Backend: {"response": [...]}
class ListImageResponseModel {
  final List<RoomImageModel> response;

  const ListImageResponseModel({required this.response});

  factory ListImageResponseModel.fromJson(Map<String, dynamic> json) {
    return ListImageResponseModel(
      response: (json['response'] as List<dynamic>? ?? [])
          .map((e) => RoomImageModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 2. Khớp với ListRoomResponse ở Backend: {"rooms": [...]}
class ListRoomResponseModel {
  final List<RoomModel> rooms;

  const ListRoomResponseModel({required this.rooms});

  factory ListRoomResponseModel.fromJson(Map<String, dynamic> json) {
    return ListRoomResponseModel(
      rooms: (json['rooms'] as List<dynamic>? ?? [])
          .map((e) => RoomModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 3. Dùng chung cho cả ListRoomByPosition & ListRoomByDistrict: {"rooms": [...], "district": "..."}
class ListNearbyRoomResponseModel {
  final List<NearbyRoomModel> rooms;
  final String? district;

  const ListNearbyRoomResponseModel({required this.rooms, this.district});

  factory ListNearbyRoomResponseModel.fromJson(Map<String, dynamic> json) {
    return ListNearbyRoomResponseModel(
      rooms: (json['rooms'] as List<dynamic>? ?? [])
          .map((e) => NearbyRoomModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      district: json['district'] as String?,
    );
  }
}
