import 'package:equatable/equatable.dart';
import 'package:roomio/features/room/domain/entities/room_request_entities.dart';

abstract class RemoteLandlordRoomEvent extends Equatable {
  const RemoteLandlordRoomEvent();

  @override
  List<Object?> get props => [];
}

/// Truyền uploadRequest để upload ảnh mới trước khi đăng phòng.
/// Nếu đã có URL ảnh, chỉ cần truyền request chứa các ảnh đã upload.
class PostRoomEvent extends RemoteLandlordRoomEvent {
  final PostRoomRequestEntity request;
  final UploadRoomImagesRequestEntity? uploadRequest;

  const PostRoomEvent({required this.request, this.uploadRequest});

  @override
  List<Object?> get props => [request, uploadRequest];
}

class UploadRoomImagesEvent extends RemoteLandlordRoomEvent {
  final UploadRoomImagesRequestEntity request;

  const UploadRoomImagesEvent({required this.request});

  @override
  List<Object?> get props => [request];
}

class GetListRoomEvent extends RemoteLandlordRoomEvent {
  const GetListRoomEvent();
}

class UpdateRoomEvent extends RemoteLandlordRoomEvent {
  final UpdateRoomRequestEntity request;
  final UploadRoomImagesRequestEntity? uploadRequest;

  const UpdateRoomEvent({required this.request, this.uploadRequest});

  @override
  List<Object?> get props => [request, uploadRequest];
}

class UpdateStatusRoomEvent extends RemoteLandlordRoomEvent {
  final String roomId;
  final String status;

  const UpdateStatusRoomEvent({required this.roomId, required this.status});

  @override
  List<Object?> get props => [roomId, status];
}
