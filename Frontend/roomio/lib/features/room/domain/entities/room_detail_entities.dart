import 'package:equatable/equatable.dart';
import 'room_entities.dart';
import 'room_sub_entities.dart';

class RoomDetailEntity extends Equatable {
  final RoomEntity room;
  final LandlordInfoEntity landlord;

  const RoomDetailEntity({required this.room, required this.landlord});

  @override
  List<Object?> get props => [room, landlord];
}
