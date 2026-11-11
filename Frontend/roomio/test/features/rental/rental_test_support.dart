import 'dart:async';
import 'package:dio/dio.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/rental/data/data_sources/remote/rental_api_service.dart';
import 'package:roomio/features/rental/data/models/rental.dart';
import 'package:roomio/features/rental/data/repository/rental_repository_impl.dart';
import 'package:roomio/features/rental/domain/entities/rental.dart';
import 'package:roomio/features/rental/domain/repository/rental_repository.dart';
import 'package:roomio/features/rental/domain/usecases/create_qr_code.dart';
import 'package:roomio/features/rental/domain/usecases/verify_qr_code.dart';
import 'package:roomio/features/rental/domain/usecases/destroy_relation.dart';
import 'package:roomio/features/rental/domain/usecases/get_my_tenants.dart';
import 'package:roomio/features/rental/domain/usecases/get_current_rent_room.dart';
import 'package:roomio/features/rental/presentation/bloc/remote/remote_rental_bloc.dart';

Map<String, dynamic> get tenantJson => {
  'rental_id': 'rental-id',
  'tenant_id': 'tenant-id',
  'full_name': 'Nguyễn Văn An',
  'avatar_url': '',
  'phone_number': '0901234567',
  'room_id': 'room-id',
  'room_name': 'Phòng gần trường đại học',
  'start_date': '2026-10-01T09:00:00',
  'status': 'active',
};
Map<String, dynamic> get rentedRoomJson => {
  'rental_id': 'rental-id',
  'start_date': '2026-10-01T09:00:00',
  'status': 'active',
  'room_id': 'room-id',
  'room_name': 'Phòng gần trường đại học',
  'room_thumbnail': '',
  'address': 'Thủ Đức, TP. Hồ Chí Minh',
  'price': 3500000,
};
TenantRentalResponse get tenant =>
    TenantRentalModelResponse.fromJson(tenantJson);
RentalRoomResponse get rentedRoom =>
    RentalModelRoomResponse.fromJson(rentedRoomJson);

RemoteRentalBloc rentalBloc(
  RentalRepository repository, {
  DateTime Function()? now,
}) => RemoteRentalBloc(
  CreateRentalQRCodeUseCase(repository),
  VerifyRentalQRCodeUseCase(repository),
  DestroyRentalRelationUseCase(repository),
  GetMyTenantsUseCase(repository),
  GetCurrentRentRoomUseCase(repository),
  now: now,
);

class RentalTestApi {
  late final Dio dio;
  late final RentalRepositoryImpl repository;
  final List<RequestOptions> requests = [];
  Object? responseData;
  Object? Function(RequestOptions)? responseFor;
  int statusCode = 200;
  DioException? error;
  RentalTestApi() {
    dio = Dio(BaseOptions(validateStatus: (_) => true));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          if (error != null) {
            handler.reject(error!);
            return;
          }
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: statusCode,
              data: responseFor == null ? responseData : responseFor!(options),
            ),
          );
        },
      ),
    );
    repository = RentalRepositoryImpl(RentalApiService(dio));
  }
  void dispose() => dio.close(force: true);
}

class FakeRentalRepository implements RentalRepository {
  List<TenantRentalResponse> tenants = [tenant];
  List<RentalRoomResponse> rooms = [rentedRoom];
  DioException? error;
  int listCalls = 0;
  int codeCalls = 0;
  int verifyCalls = 0;
  String? createdRoom;
  String? destroyedId;
  RentalVerifyRequest? verifiedRequest;
  RentalResponse code = const RentalResponse(
    qrToken: '012345',
    expiresInSecond: 60,
  );
  RentalVerifyResponse verification = const RentalVerifyResponse(
    message: 'Đã xác nhận',
    isValid: true,
  );
  Completer<DataState<RentalResponse>>? creating;
  Completer<DataState<RentalVerifyResponse>>? verifying;
  final List<Completer<DataState<List<TenantRentalResponse>>>> loads = [];
  DataState<T> result<T>(T data) =>
      error == null ? DataSuccess(data) : DataError(error!);
  @override
  Future<DataState<RentalResponse>> createQRCode(String roomId) async {
    codeCalls++;
    createdRoom = roomId;
    return creating == null ? result(code) : await creating!.future;
  }

  @override
  Future<DataState<RentalVerifyResponse>> verifyQRCode(
    RentalVerifyRequest request,
  ) async {
    verifyCalls++;
    verifiedRequest = request;
    return verifying == null ? result(verification) : await verifying!.future;
  }

  @override
  Future<DataState<String>> destroyRelation(String rentalRelationId) async {
    destroyedId = rentalRelationId;
    return result('Đã kết thúc thuê');
  }

  @override
  Future<DataState<List<TenantRentalResponse>>> getMyTenants() async {
    final index = listCalls++;
    return index < loads.length ? await loads[index].future : result(tenants);
  }

  @override
  Future<DataState<List<RentalRoomResponse>>> getCurrentRentRoom() async {
    listCalls++;
    return result(rooms);
  }
}
