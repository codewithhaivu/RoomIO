import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/saved_room/data/data_sources/remote/save_room_api_service.dart';
import 'package:roomio/features/saved_room/domain/entities/save_room.dart';
import 'package:roomio/features/saved_room/domain/repository/save_room_repository.dart';

class SaveRoomRepositoryImpl implements SaveRoomRepository {
  final SavedRoomApiService _api;

  SaveRoomRepositoryImpl(this._api);

  @override
  Future<DataState<ListSavedRoomResponse>> getSavedRooms() => _request(
    () => _api.getSavedRoomInARoom(),
    (model) => model.toEntity(),
    path: '/',
    method: 'GET',
  );

  @override
  Future<DataState<String>> saveRoom(String roomId) => _request(
    () => _api.postSavedRoomInARoom(roomId),
    (model) => model.message,
    path: '/$roomId',
    method: 'POST',
  );

  @override
  Future<DataState<String>> unsaveRoom(String roomId) => _request(
    () => _api.deleteSavedRoomInARoom(roomId),
    (model) => model.message,
    path: '/$roomId',
    method: 'DELETE',
  );

  Future<DataState<T>> _request<M, T>(
    Future<HttpResponse<M>> Function() request,
    T Function(M) convert, {
    required String path,
    required String method,
  }) async {
    try {
      final result = await request();
      final status = result.response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw DioException.badResponse(
          statusCode: status,
          requestOptions: result.response.requestOptions,
          response: result.response,
        );
      }
      return DataSuccess(convert(result.data));
    } on DioException catch (error) {
      return DataError(error);
    } catch (error, stackTrace) {
      return DataError(
        DioException(
          requestOptions: RequestOptions(path: path, method: method),
          error: error,
          stackTrace: stackTrace,
          message: 'Dữ liệu phòng đã lưu không hợp lệ.',
        ),
      );
    }
  }
}
