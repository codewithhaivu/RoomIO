import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/room/domain/entities/room_request_entities.dart';
import 'package:roomio/features/room/domain/entities/room_sub_entities.dart';
import 'package:roomio/features/room/domain/usecases/landlord/post_room.dart';
import 'package:roomio/features/room/domain/usecases/landlord/upload_images.dart';
import 'package:roomio/features/room/domain/usecases/landlord/get_list_room.dart';
import 'package:roomio/features/room/domain/usecases/landlord/update_room.dart';
import 'package:roomio/features/room/domain/usecases/landlord/update_status_room.dart';
import 'package:roomio/features/room/presentation/bloc/remote/landlord/remote_landlord_room_event.dart';
import 'package:roomio/features/room/presentation/bloc/remote/landlord/remote_landlord_room_state.dart';

class RemoteLandlordRoomBloc
    extends Bloc<RemoteLandlordRoomEvent, RemoteLandlordRoomState> {
  final PostRoomUseCase _postRoomUseCase;
  final UploadRoomImagesUseCase _uploadRoomImagesUseCase;
  final GetListRoomUseCase _getListRoomUseCase;
  final UpdateRoomUseCase _updateRoomUseCase;
  final UpdateStatusRoomUseCase _updateStatusRoomUseCase;

  RemoteLandlordRoomBloc(
    this._postRoomUseCase,
    this._uploadRoomImagesUseCase,
    this._getListRoomUseCase,
    this._updateRoomUseCase,
    this._updateStatusRoomUseCase,
  ) : super(const RemoteLandlordRoomInitial()) {
    on<PostRoomEvent>(postRoom);
    on<UploadRoomImagesEvent>(uploadImages);
    on<GetListRoomEvent>(getListRoom);
    on<UpdateRoomEvent>(updateRoom);
    on<UpdateStatusRoomEvent>(updateStatusRoom);
  }

  Future<void> postRoom(
    PostRoomEvent event,
    Emitter<RemoteLandlordRoomState> emit,
  ) async {
    emit(const RemoteLandlordRoomLoading());
    final request = event.request;
    List<RoomImageEntity> images = request.images;
    final uploadRequest = event.uploadRequest;

    if (uploadRequest != null) {
      final uploadState = await _uploadRoomImagesUseCase(uploadRequest);
      if (uploadState is DataSuccess) {
        images = [...images, ...uploadState.data!];
      } else {
        emit(RemoteLandlordRoomFailure(dio: uploadState.error!));
        return;
      }
    }

    final dataState = await _postRoomUseCase(
      PostRoomRequestEntity(
        name: request.name,
        area: request.area,
        waterFee: request.waterFee,
        serviceFee: request.serviceFee,
        parkingFee: request.parkingFee,
        rentalPrice: request.rentalPrice,
        electricityFee: request.electricityFee,
        status: request.status,
        roomType: request.roomType,
        location: request.location,
        interiors: request.interiors,
        amenities: request.amenities,
        images: images,
      ),
    );

    if (dataState is DataSuccess) {
      emit(RemotePostRoomSuccess(room: dataState.data!));
    } else {
      emit(RemoteLandlordRoomFailure(dio: dataState.error!));
    }
  }

  Future<void> uploadImages(
    UploadRoomImagesEvent event,
    Emitter<RemoteLandlordRoomState> emit,
  ) async {
    emit(const RemoteLandlordRoomLoading());
    final dataState = await _uploadRoomImagesUseCase(event.request);

    if (dataState is DataSuccess) {
      emit(RemoteUploadRoomImagesSuccess(images: dataState.data!));
    } else {
      emit(RemoteLandlordRoomFailure(dio: dataState.error!));
    }
  }

  Future<void> getListRoom(
    GetListRoomEvent event,
    Emitter<RemoteLandlordRoomState> emit,
  ) async {
    emit(const RemoteLandlordRoomLoading());
    final dataState = await _getListRoomUseCase(null);

    if (dataState is DataSuccess) {
      emit(RemoteGetListRoomSuccess(rooms: dataState.data!));
    } else {
      emit(RemoteLandlordRoomFailure(dio: dataState.error!));
    }
  }

  Future<void> updateRoom(
    UpdateRoomEvent event,
    Emitter<RemoteLandlordRoomState> emit,
  ) async {
    emit(const RemoteLandlordRoomLoading());
    final request = event.request;
    List<RoomImageEntity>? images = request.images;
    final uploadRequest = event.uploadRequest;
    if (uploadRequest != null) {
      final uploadState = await _uploadRoomImagesUseCase(uploadRequest);
      if (uploadState is DataSuccess) {
        images = [...?images, ...uploadState.data!];
      } else {
        emit(RemoteLandlordRoomFailure(dio: uploadState.error!));
        return;
      }
    }
    final dataState = await _updateRoomUseCase(
      UpdateRoomRequestEntity(
        roomId: request.roomId,
        name: request.name,
        area: request.area,
        waterFee: request.waterFee,
        serviceFee: request.serviceFee,
        parkingFee: request.parkingFee,
        rentalPrice: request.rentalPrice,
        electricityFee: request.electricityFee,
        status: request.status,
        roomType: request.roomType,
        location: request.location,
        interiors: request.interiors,
        amenities: request.amenities,
        images: images,
      ),
    );

    if (dataState is DataSuccess) {
      emit(RemoteUpdateRoomSuccess(roomDetail: dataState.data!));
    } else {
      emit(RemoteLandlordRoomFailure(dio: dataState.error!));
    }
  }

  Future<void> updateStatusRoom(
    UpdateStatusRoomEvent event,
    Emitter<RemoteLandlordRoomState> emit,
  ) async {
    emit(const RemoteLandlordRoomLoading());
    final dataState = await _updateStatusRoomUseCase(
      UpdateRoomStatusRequestEntity(roomId: event.roomId, status: event.status),
    );

    if (dataState is DataSuccess) {
      emit(RemoteUpdateStatusRoomSuccess(message: dataState.data!));
    } else {
      emit(RemoteLandlordRoomFailure(dio: dataState.error!));
    }
  }
}
