import 'dart:io';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/room/domain/entities/nearby_room_entities.dart';
import 'package:roomio/features/room/domain/entities/room_detail_entities.dart';
import 'package:roomio/features/room/domain/entities/room_entities.dart';
import 'package:roomio/features/room/domain/entities/room_place_suggestion.dart';
import 'package:roomio/features/room/domain/entities/room_sub_entities.dart';

abstract class RoomRepository {
  // ================= LANDLORD =================

  Future<DataState<RoomEntity>> postRoom(
    String name,
    double area,
    double waterFee,
    double serviceFee,
    double parkingFee,
    double rentalPrice,
    double electricityFee,
    String status,
    String roomType,
    LocationEntity location,
    List<String> interiors,
    List<String> amenities,
    List<RoomImageEntity> images,
  );

  Future<DataState<List<RoomImageEntity>>> uploadImages(
    List<File> images,
    List<bool> isThumbnails,
  );

  Future<DataState<List<RoomEntity>>> getListRoom();

  Future<DataState<String>> updateStatusRoom(String roomId, String status);

  Future<DataState<RoomDetailEntity>> updateRoom(
    String roomId, {
    String? name,
    double? area,
    double? waterFee,
    double? serviceFee,
    double? parkingFee,
    double? rentalPrice,
    double? electricityFee,
    String? status,
    String? roomType,
    LocationEntity? location,
    List<String>? interiors,
    List<String>? amenities,
    List<RoomImageEntity>? images,
  });

  // ================= COMMON =================

  Future<DataState<RoomDetailEntity>> getDetailRoom(String roomId);

  // ================= TENANT =================

  Future<DataState<List<NearbyRoomEntity>>> searchRoomByPosition(
    double latitude,
    double longitude,
    double radius,
  );

  Future<DataState<List<NearbyRoomEntity>>> searchRoomsByArea(
    String locationId,
    String district, {
    double radius = 10,
  });

  Future<DataState<List<LocationSuggestion>>> getLocationSuggestion();

  
}
