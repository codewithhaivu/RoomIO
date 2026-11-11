import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/room/domain/usecases/get_detail_room.dart';
import 'package:roomio/features/room/presentation/bloc/remote/detail/remote_room_detail_event.dart';
import 'package:roomio/features/room/presentation/bloc/remote/detail/remote_room_detail_state.dart';

class RemoteRoomDetailBloc
    extends Bloc<RemoteRoomDetailEvent, RemoteRoomDetailState> {
  final GetDetailRoomUseCase _getDetailRoomUseCase;

  RemoteRoomDetailBloc(this._getDetailRoomUseCase)
    : super(const RemoteRoomDetailInitial()) {
    on<GetDetailRoomEvent>(getDetailRoom);
  }

  Future<void> getDetailRoom(
    GetDetailRoomEvent event,
    Emitter<RemoteRoomDetailState> emit,
  ) async {
    emit(const RemoteRoomDetailLoading());
    final dataState = await _getDetailRoomUseCase(event.roomId);

    if (dataState is DataSuccess) {
      emit(RemoteRoomDetailSuccess(roomDetail: dataState.data!));
    } else {
      emit(RemoteRoomDetailFailure(dio: dataState.error!));
    }
  }
}
