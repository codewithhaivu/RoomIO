import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/room/domain/entities/room_catalog_entity.dart';
import 'package:roomio/features/room/domain/usecases/get_room_catalog.dart';

abstract class RemoteRoomCatalogState extends Equatable {
  const RemoteRoomCatalogState();
  @override
  List<Object?> get props => [];
}

class RemoteRoomCatalogLoading extends RemoteRoomCatalogState {
  const RemoteRoomCatalogLoading();
}

class RemoteRoomCatalogSuccess extends RemoteRoomCatalogState {
  final RoomCatalogEntity catalog;
  const RemoteRoomCatalogSuccess(this.catalog);
  @override
  List<Object?> get props => [catalog];
}

class RemoteRoomCatalogFailure extends RemoteRoomCatalogState {
  final DioException dio;
  const RemoteRoomCatalogFailure(this.dio);
  @override
  List<Object?> get props => [dio];
}

class RemoteRoomCatalogCubit extends Cubit<RemoteRoomCatalogState> {
  final GetRoomCatalogUseCase _getRoomCatalogUseCase;
  RemoteRoomCatalogCubit(this._getRoomCatalogUseCase)
    : super(const RemoteRoomCatalogLoading());

  Future<void> loadCatalog() async {
    emit(const RemoteRoomCatalogLoading());
    final result = await _getRoomCatalogUseCase(null);
    if (isClosed) return;
    if (result is DataSuccess) {
      emit(RemoteRoomCatalogSuccess(result.data!));
    } else {
      emit(RemoteRoomCatalogFailure(result.error!));
    }
  }
}
