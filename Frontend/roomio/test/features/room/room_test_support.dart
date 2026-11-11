import 'dart:io';
import 'package:dio/dio.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/room/data/data_sources/remote/room_api_service.dart';
import 'package:roomio/features/room/data/repository/room_repository_impl.dart';
import 'package:roomio/features/room/domain/entities/room_request_entities.dart';
import 'package:roomio/features/room/domain/entities/room_sub_entities.dart';

const location = LocationEntity(
  name: 'Thu Duc',
  longitude: 106.7,
  latitude: 10.8,
);
const image = RoomImageEntity(
  imageUrl: 'https://example.com/room.jpg',
  publicId: 'room-image',
  isThumbnail: true,
);
const postRequest = PostRoomRequestEntity(
  name: 'Room',
  area: 25,
  waterFee: 1,
  serviceFee: 2,
  parkingFee: 3,
  rentalPrice: 4000000,
  electricityFee: 4,
  status: 'AVAILABLE',
  roomType: 'STUDIO',
  location: location,
  interiors: ['interior-id'],
  amenities: ['amenity-id'],
  images: [image],
);

Map<String, dynamic> get imageJson => {
  'image_url': image.imageUrl,
  'public_id': image.publicId,
  'is_thumbnail': image.isThumbnail,
};
Map<String, dynamic> get roomJson => {
  'id': 'room-id',
  'name': postRequest.name,
  'area': postRequest.area,
  'water_fee': postRequest.waterFee,
  'service_fee': postRequest.serviceFee,
  'parking_fee': postRequest.parkingFee,
  'rental_price': postRequest.rentalPrice,
  'electricity_fee': postRequest.electricityFee,
  'status': postRequest.status,
  'room_type': postRequest.roomType,
  'location': {
    'name': location.name,
    'longitude': location.longitude,
    'latitude': location.latitude,
  },
  'interiors': [
    {'id': 'interior-id', 'name': 'Bed'},
  ],
  'amenities': [
    {'id': 'amenity-id', 'name': 'Wifi'},
  ],
  'image': {
    'response': [imageJson],
  },
};
Map<String, dynamic> get detailJson => {
  'room': roomJson,
  'landlord': {'full_name': 'Landlord', 'gender': 'MALE', 'is_verify': true},
};
Map<String, dynamic> get nearbyJson => {
  'id': 'room-id',
  'name': 'Room',
  'area': 25,
  'rental_price': 4000000,
  'status': 'AVAILABLE',
  'distance': 1.5,
  'room_type': 'STUDIO',
  'location_name': 'Thu Duc',
  'image_url': image.imageUrl,
};

class RoomTestApi {
  late final Dio dio;
  late final RoomRepositoryImpl repository;
  final List<RequestOptions> requests = [];
  Object? responseData;
  int statusCode = HttpStatus.ok;
  DioException? error;
  Object? Function(RequestOptions)? responseFor;
  late final Directory directory;
  late final File imageFile;

  RoomTestApi() {
    directory = Directory.systemTemp.createTempSync('roomio_room_test_');
    imageFile = File('${directory.path}${Platform.pathSeparator}room.jpg')
      ..writeAsBytesSync([1, 2, 3]);
    dio = Dio(BaseOptions(validateStatus: (_) => true));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final failure = error;
          if (failure != null) {
            handler.reject(failure);
            return;
          }
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: statusCode,
              statusMessage: 'test response',
              data: responseFor == null ? responseData : responseFor!(options),
            ),
          );
        },
      ),
    );
    repository = RoomRepositoryImpl(RoomApiService(dio));
  }

  Future<DataState<dynamic>> postRoom() => repository.postRoom(
    postRequest.name,
    postRequest.area,
    postRequest.waterFee,
    postRequest.serviceFee,
    postRequest.parkingFee,
    postRequest.rentalPrice,
    postRequest.electricityFee,
    postRequest.status,
    postRequest.roomType,
    postRequest.location,
    postRequest.interiors,
    postRequest.amenities,
    postRequest.images,
  );

  void dispose() {
    dio.close(force: true);
    imageFile.deleteSync();
    directory.deleteSync();
  }
}
