

import 'package:equatable/equatable.dart';

class NearbyRoomEntity extends Equatable {
  final String id;
  final String name;
  final double area;
  final double rentalPrice;
  final String status;
  final double distance;
  final String roomType;
  final String locationName;
  final String imageUrl;
  final bool isSaved;

  const NearbyRoomEntity({
    required this.id,
    required this.name,
    required this.area,
    required this.rentalPrice,
    required this.status,
    required this.distance,
    required this.roomType,
    required this.locationName,
    required this.imageUrl,
    required this.isSaved,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    area,
    rentalPrice,
    status,
    distance,
    roomType,
    locationName,
    imageUrl,
    isSaved,
  ];
}
