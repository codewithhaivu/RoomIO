import 'package:dio/dio.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/saved_room/data/data_sources/remote/save_room_api_service.dart';
import 'package:roomio/features/saved_room/data/repository/save_room_repository_impl.dart';
import 'package:roomio/features/saved_room/domain/entities/save_room.dart';
import 'package:roomio/features/saved_room/domain/repository/save_room_repository.dart';
import 'package:roomio/features/saved_room/domain/usecases/get_saved_rooms.dart';
import 'package:roomio/features/saved_room/domain/usecases/save_room.dart';
import 'package:roomio/features/saved_room/domain/usecases/unsave_room.dart';
import 'package:roomio/features/saved_room/presentation/cubit/saved_rooms_cubit.dart';

const room = RoomResponse(
  id: 'room-id',
  name: 'Room',
  area: 25,
  rentalPrice: 4000000,
  status: 'AVAILABLE',
  roomType: 'STUDIO',
  locationName: 'Thủ Đức',
  imageUrl: '',
);
const otherRoom = RoomResponse(
  id: 'other-room',
  name: 'Other Room',
  area: 30,
  rentalPrice: 5000000,
  status: 'AVAILABLE',
  roomType: 'ROOM',
  locationName: 'Quận 1',
  imageUrl: '',
);

Map<String, dynamic> roomJson() => {
  'id': room.id,
  'name': room.name,
  'area': 25,
  'rental_price': 4000000,
  'status': room.status,
  'room_type': room.roomType,
  'location_name': room.locationName,
  'image_url': null,
};

DioException failure({int status = 403}) => DioException(
  requestOptions: RequestOptions(path: '/saved-rooms/room-id'),
  response: Response(
    requestOptions: RequestOptions(path: '/saved-rooms/room-id'),
    statusCode: status,
    data: {'detail': 'Không thể thay đổi phòng đã lưu.'},
  ),
  type: DioExceptionType.badResponse,
);

class SavedRoomTestApi {
  final dio = Dio();
  final requests = <RequestOptions>[];
  Object? data;
  int status = 200;
  DioException? error;
  late final SaveRoomRepositoryImpl repository;

  SavedRoomTestApi() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          if (error != null) {
            handler.reject(error!);
          } else {
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: status,
                data: data,
              ),
            );
          }
        },
      ),
    );
    repository = SaveRoomRepositoryImpl(SavedRoomApiService(dio));
  }
}

class FakeSaveRoomRepository implements SaveRoomRepository {
  List<RoomResponse> rooms = [];
  Future<DataState<ListSavedRoomResponse>> Function()? onGet;
  Future<DataState<String>> Function(String)? onSave;
  Future<DataState<String>> Function(String)? onUnsave;
  int gets = 0;
  final saves = <String>[];
  final unsaves = <String>[];

  SavedRoomsCubit cubit() => SavedRoomsCubit(
    GetSavedRoomsUseCase(this),
    SaveRoomUseCase(this),
    UnsaveRoomUseCase(this),
  );

  @override
  Future<DataState<ListSavedRoomResponse>> getSavedRooms() async {
    gets++;
    return onGet == null
        ? DataSuccess(ListSavedRoomResponse(rooms: List.of(rooms)))
        : await onGet!();
  }

  @override
  Future<DataState<String>> saveRoom(String id) async {
    saves.add(id);
    final result = onSave == null
        ? const DataSuccess<String>('Saved')
        : await onSave!(id);
    if (result is DataSuccess<String>) {
      rooms = [
        id == room.id ? room : otherRoom,
        ...rooms.where((item) => item.id != id),
      ];
    }
    return result;
  }

  @override
  Future<DataState<String>> unsaveRoom(String id) async {
    unsaves.add(id);
    final result = onUnsave == null
        ? const DataSuccess<String>('Removed')
        : await onUnsave!(id);
    if (result is DataSuccess<String>) {
      rooms = rooms.where((item) => item.id != id).toList();
    }
    return result;
  }
}
