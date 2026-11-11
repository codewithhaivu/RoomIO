import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:roomio/core/constants/constants.dart';
import 'package:roomio/features/room/data/models/room_sub_models.dart';

class RoomCatalogApiService {
  final Dio _dio;
  final String baseUrl;

  RoomCatalogApiService(this._dio, {String? baseUrl})
    : baseUrl = baseUrl ?? Uri.parse(roomAPIBaseUrl).resolve('/').toString();

  Future<HttpResponse<List<InteriorModel>>> getInteriors() async {
    final response = await _dio.get<Map<String, dynamic>>('${baseUrl}interior');
    final data = (response.data?['data'] as List<dynamic>? ?? [])
        .map((item) => InteriorModel.fromJson(item as Map<String, dynamic>))
        .toList();
    return HttpResponse(data, response);
  }

  Future<HttpResponse<List<AmenityModel>>> getAmenities() async {
    final response = await _dio.get<Map<String, dynamic>>('${baseUrl}amenitie');
    final data = (response.data?['data'] as List<dynamic>? ?? [])
        .map((item) => AmenityModel.fromJson(item as Map<String, dynamic>))
        .toList();
    return HttpResponse(data, response);
  }
}
