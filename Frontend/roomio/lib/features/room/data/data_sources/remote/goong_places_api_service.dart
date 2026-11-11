import 'package:dio/dio.dart';
import 'package:roomio/features/room/domain/entities/room_place_suggestion.dart';

/// Dio riêng để không gửi token đăng nhập Roomio tới Goong.
class GoongPlacesApiService {
  final Dio _dio;
  final String apiKey;

  GoongPlacesApiService({
    Dio? dio,
    this.apiKey = const String.fromEnvironment('GOONG_API_KEY'),
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: 'https://rsapi.goong.io/',
               connectTimeout: const Duration(seconds: 8),
               receiveTimeout: const Duration(seconds: 8),
               headers: {'Accept': 'application/json'},
             ),
           );

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, dynamic> parameters,
  ) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw const RoomPlacesException(RoomPlacesIssue.configuration);
    }
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: {'api_key': key, ...parameters},
    );
    return response.data ?? {};
  }

  // Goong V2 cung cấp dữ liệu địa chỉ Việt Nam, không ép về một thành phố cố định.
  Future<Map<String, dynamic>> autocomplete(String query) =>
      _get('v2/place/autocomplete', {'input': query.trim(), 'limit': 5});

  Future<Map<String, dynamic>> placeDetails(String placeId) =>
      _get('v2/place/detail', {'place_id': placeId});
}
