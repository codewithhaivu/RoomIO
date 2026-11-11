import 'package:equatable/equatable.dart';

abstract class RemoteRoomDetailEvent extends Equatable {
  const RemoteRoomDetailEvent();

  @override
  List<Object?> get props => [];
}

class GetDetailRoomEvent extends RemoteRoomDetailEvent {
  final String roomId;

  const GetDetailRoomEvent({required this.roomId});

  @override
  List<Object?> get props => [roomId];
}
