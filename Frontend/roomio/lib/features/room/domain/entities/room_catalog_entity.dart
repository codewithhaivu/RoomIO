import 'package:equatable/equatable.dart';
import 'package:roomio/features/room/domain/entities/room_sub_entities.dart';

class RoomCatalogEntity extends Equatable {
  final List<InteriorEntity> interiors;
  final List<AmenityEntity> amenities;

  const RoomCatalogEntity({required this.interiors, required this.amenities});

  @override
  List<Object?> get props => [interiors, amenities];
}
