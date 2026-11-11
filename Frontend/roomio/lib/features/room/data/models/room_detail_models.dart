import 'package:roomio/features/room/domain/entities/room_detail_entities.dart';
import 'room_models.dart';
import 'room_sub_models.dart';

class RoomDetailModel extends RoomDetailEntity {
  const RoomDetailModel({required super.room, required super.landlord});

  factory RoomDetailModel.fromJson(Map<String, dynamic> json) {
    return RoomDetailModel(
      room: RoomModel.fromJson(json['room']),
      landlord: LandlordInfoModel.fromJson(json['landlord']),
    );
  }
}
