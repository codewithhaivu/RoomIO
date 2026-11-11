import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:roomio/features/room/domain/entities/room_detail_entities.dart';

abstract class RemoteRoomDetailState extends Equatable {
  const RemoteRoomDetailState();

  @override
  List<Object?> get props => [];
}

class RemoteRoomDetailInitial extends RemoteRoomDetailState {
  const RemoteRoomDetailInitial();
}

class RemoteRoomDetailLoading extends RemoteRoomDetailState {
  const RemoteRoomDetailLoading();
}

class RemoteRoomDetailSuccess extends RemoteRoomDetailState {
  final RoomDetailEntity roomDetail;

  const RemoteRoomDetailSuccess({required this.roomDetail});

  @override
  List<Object?> get props => [roomDetail];
}

class RemoteRoomDetailFailure extends RemoteRoomDetailState {
  final DioException dio;

  const RemoteRoomDetailFailure({required this.dio});

  @override
  List<Object?> get props => [dio];
}
