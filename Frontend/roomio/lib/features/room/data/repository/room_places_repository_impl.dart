import 'package:dio/dio.dart';
import 'package:roomio/features/room/data/data_sources/remote/goong_places_api_service.dart';
import 'package:roomio/features/room/domain/entities/room_place_suggestion.dart';
import 'package:roomio/features/room/domain/entities/room_sub_entities.dart';
import 'package:roomio/features/room/domain/repository/room_places_repository.dart';

class RoomPlacesRepositoryImpl implements RoomPlacesRepository {
  final GoongPlacesApiService _api;
  RoomPlacesRepositoryImpl(this._api);

  Future<T> _request<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      if ([
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout,
      ].contains(error.type)) {
        throw const RoomPlacesException(RoomPlacesIssue.timeout);
      }
      throw RoomPlacesException(
        error.response?.statusCode == 403 || error.response?.statusCode == 401
            ? RoomPlacesIssue.denied
            : RoomPlacesIssue.unavailable,
      );
    } on FormatException {
      throw const RoomPlacesException(RoomPlacesIssue.unavailable);
    } on TypeError {
      throw const RoomPlacesException(RoomPlacesIssue.unavailable);
    }
  }

  void _validateStatus(Map<String, dynamic> data, {bool allowEmpty = false}) {
    switch (data['status']) {
      case 'OK':
        return;
      case 'ZERO_RESULTS':
        if (allowEmpty) return;
        throw const RoomPlacesException(RoomPlacesIssue.notFound);
      case 'NOT_FOUND':
        throw const RoomPlacesException(RoomPlacesIssue.notFound);
      case 'REQUEST_DENIED':
      case 'PERMISSION_DENIED':
      case 'UNAUTHENTICATED':
      case 'INVALID_API_KEY':
        throw const RoomPlacesException(RoomPlacesIssue.denied);
      default:
        throw const RoomPlacesException(RoomPlacesIssue.unavailable);
    }
  }

  @override
  Future<List<RoomPlaceSuggestion>> autocomplete(String query) =>
      _request(() async {
        final input = query.trim();
        if (input.length < 3) return [];
        final data = await _api.autocomplete(input);
        _validateStatus(data, allowEmpty: true);
        if (data['status'] == 'ZERO_RESULTS') return [];
        final predictions = data['predictions'];
        if (predictions is! List) {
          throw const RoomPlacesException(RoomPlacesIssue.unavailable);
        }
        return predictions
            .whereType<Map>()
            .map((item) {
              final id = item['place_id'];
              final text = item['description'];
              return id is! String ||
                      id.trim().isEmpty ||
                      text is! String ||
                      text.trim().isEmpty
                  ? null
                  : RoomPlaceSuggestion(placeId: id, description: text.trim());
            })
            .whereType<RoomPlaceSuggestion>()
            .take(5)
            .toList();
      });

  @override
  Future<LocationEntity> resolvePlace(String placeId) => _request(() async {
    final data = await _api.placeDetails(placeId);
    _validateStatus(data);
    final result = data['result'] as Map<String, dynamic>?;
    final address = result?['formatted_address'] as String?;
    final geometry = result?['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;
    final latitude = (location?['lat'] as num?)?.toDouble();
    final longitude = (location?['lng'] as num?)?.toDouble();
    if (address == null ||
        address.trim().isEmpty ||
        latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      throw const RoomPlacesException(RoomPlacesIssue.notFound);
    }
    return LocationEntity(
      name: address.trim(),
      latitude: latitude,
      longitude: longitude,
    );
  });
}
