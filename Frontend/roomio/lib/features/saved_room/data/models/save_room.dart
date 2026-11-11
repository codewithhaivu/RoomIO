import 'package:roomio/features/saved_room/domain/entities/save_room.dart';

class RoomResponseModel extends RoomResponse {
  const RoomResponseModel({
    required super.id,
    required super.name,
    required super.area,
    required super.rentalPrice,
    required super.status,
    required super.roomType,
    required super.locationName,
    required super.imageUrl,
  });

  factory RoomResponseModel.fromJson(Map<String, dynamic> json) =>
      RoomResponseModel(
        id: json['id'] as String,
        name: json['name'] as String,
        area: (json['area'] as num).toDouble(),
        rentalPrice: (json['rental_price'] as num).toDouble(),
        status: json['status'] as String,
        roomType: json['room_type'] as String,
        locationName: json['location_name'] as String,
        imageUrl: json['image_url'] as String? ?? '',
      );

  RoomResponse toEntity() => RoomResponse(
    id: id,
    name: name,
    area: area,
    rentalPrice: rentalPrice,
    status: status,
    roomType: roomType,
    locationName: locationName,
    imageUrl: imageUrl,
  );
}

class ListSavedRoomResponseModel extends ListSavedRoomResponse {
  const ListSavedRoomResponseModel({
    required List<RoomResponseModel> super.rooms,
  });

  factory ListSavedRoomResponseModel.fromJson(Map<String, dynamic> json) =>
      ListSavedRoomResponseModel(
        rooms: (json['rooms'] as List<dynamic>? ?? [])
            .map(
              (room) =>
                  RoomResponseModel.fromJson(room as Map<String, dynamic>),
            )
            .toList(),
      );

  ListSavedRoomResponse toEntity() => ListSavedRoomResponse(
    rooms: List.unmodifiable(
      rooms.cast<RoomResponseModel>().map((room) => room.toEntity()),
    ),
  );
}

class MessageResponseModel {
  final String message;
  const MessageResponseModel({required this.message});

  factory MessageResponseModel.fromJson(Map<String, dynamic> json) =>
      MessageResponseModel(message: json['message'] as String);
}
