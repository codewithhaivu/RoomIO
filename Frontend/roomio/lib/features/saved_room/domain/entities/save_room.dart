import 'package:equatable/equatable.dart';
import 'package:roomio/features/room/domain/entities/nearby_room_entities.dart';

class RoomResponse extends Equatable {
  final String id;
  final String name;
  final double area;
  final double rentalPrice;
  final String status;
  final String roomType;
  final String locationName;
  final String imageUrl;

  const RoomResponse({
    required this.id,
    required this.name,
    required this.area,
    required this.rentalPrice,
    required this.status,
    required this.roomType,
    required this.locationName,
    required this.imageUrl,
  });

  factory RoomResponse.fromNearbyRoom(NearbyRoomEntity room) => RoomResponse(
    id: room.id,
    name: room.name,
    area: room.area,
    rentalPrice: room.rentalPrice,
    status: room.status,
    roomType: room.roomType,
    locationName: room.locationName,
    imageUrl: room.imageUrl,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    area,
    rentalPrice,
    status,
    roomType,
    locationName,
    imageUrl,
  ];
}

class ListSavedRoomResponse extends Equatable {
  final List<RoomResponse> rooms;

  const ListSavedRoomResponse({required this.rooms});

  @override
  List<Object?> get props => [rooms];
}
