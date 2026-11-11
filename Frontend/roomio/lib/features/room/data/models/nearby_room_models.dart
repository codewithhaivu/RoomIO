import 'package:roomio/features/room/domain/entities/nearby_room_entities.dart';

class NearbyRoomModel extends NearbyRoomEntity {
  const NearbyRoomModel({
    required super.id,
    required super.name,
    required super.area,
    required super.rentalPrice,
    required super.status,
    required super.distance,
    required super.roomType,
    required super.locationName,
    required super.imageUrl,
    required super.isSaved,
  });

  factory NearbyRoomModel.fromJson(Map<String, dynamic> json) {
    return NearbyRoomModel(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      area: (json['area'] as num).toDouble(),
      rentalPrice: (json['rental_price'] as num).toDouble(),
      status: json['status'] ?? '',
      distance: (json['distance'] as num).toDouble(),
      roomType: json['room_type'] ?? '',
      locationName: json['location_name'] ?? '',
      imageUrl: json['image_url'] ?? '',
      isSaved: (json['isSaved'] ?? json['is_saved']) as bool? ?? false,
    );
  }
}
