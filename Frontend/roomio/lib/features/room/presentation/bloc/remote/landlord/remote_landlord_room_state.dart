import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:roomio/features/room/domain/entities/room_entities.dart';
import 'package:roomio/features/room/domain/entities/room_detail_entities.dart';
import 'package:roomio/features/room/domain/entities/room_sub_entities.dart';

abstract class RemoteLandlordRoomState extends Equatable {
  const RemoteLandlordRoomState();

  @override
  List<Object?> get props => [];
}

class RemoteLandlordRoomInitial extends RemoteLandlordRoomState {
  const RemoteLandlordRoomInitial();
}

class RemoteLandlordRoomLoading extends RemoteLandlordRoomState {
  const RemoteLandlordRoomLoading();
}

class RemotePostRoomSuccess extends RemoteLandlordRoomState {
  final RoomEntity room;

  const RemotePostRoomSuccess({required this.room});

  @override
  List<Object?> get props => [room];
}

class RemoteUploadRoomImagesSuccess extends RemoteLandlordRoomState {
  final List<RoomImageEntity> images;

  const RemoteUploadRoomImagesSuccess({required this.images});

  @override
  List<Object?> get props => [images];
}

class RemoteGetListRoomSuccess extends RemoteLandlordRoomState {
  final List<RoomEntity> rooms;

  const RemoteGetListRoomSuccess({required this.rooms});

  @override
  List<Object?> get props => [rooms];
}

class RemoteUpdateRoomSuccess extends RemoteLandlordRoomState {
  final RoomDetailEntity roomDetail;

  const RemoteUpdateRoomSuccess({required this.roomDetail});

  @override
  List<Object?> get props => [roomDetail];
}

class RemoteUpdateStatusRoomSuccess extends RemoteLandlordRoomState {
  final String message;

  const RemoteUpdateStatusRoomSuccess({required this.message});

  @override
  List<Object?> get props => [message];
}

class RemoteLandlordRoomFailure extends RemoteLandlordRoomState {
  final DioException dio;

  const RemoteLandlordRoomFailure({required this.dio});

  @override
  List<Object?> get props => [dio];
}
