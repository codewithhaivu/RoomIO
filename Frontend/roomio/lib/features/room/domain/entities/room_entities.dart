import 'package:equatable/equatable.dart';
import 'room_sub_entities.dart';

class RoomEntity extends Equatable {
  final String id;
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
  final List<InteriorEntity> interiors;
  final List<AmenityEntity> amenities;
  final List<RoomImageEntity> images; // Đã làm phẳng từ ListImageResponse

  const RoomEntity({
    required this.id,
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
    id,
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
