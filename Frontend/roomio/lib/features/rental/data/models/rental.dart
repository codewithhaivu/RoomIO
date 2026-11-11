import 'package:roomio/features/rental/domain/entities/rental.dart';

class RentalModelResponse extends RentalResponse {
  const RentalModelResponse({
    required super.qrToken,
    required super.expiresInSecond,
  });

  factory RentalModelResponse.fromJson(Map<String, dynamic> json) {
    return RentalModelResponse(
      qrToken: json['qr_token'] ?? '',
      expiresInSecond: json['expires_in_second'] ?? 0,
    );
  }
}

class RentalModelVerifyResponse extends RentalVerifyResponse {
  const RentalModelVerifyResponse({
    required super.message,
    required super.isValid,
  });

  factory RentalModelVerifyResponse.fromJson(Map<String, dynamic> json) {
    return RentalModelVerifyResponse(
      message: json['message'] ?? '',
      isValid: json['id_valid'] as bool? ?? json['is_valid'] as bool? ?? false,
    );
  }
}

class RentalModelVerifyRequest extends RentalVerifyRequest {
  factory RentalModelVerifyRequest.fromEntity(RentalVerifyRequest entity) =>
      RentalModelVerifyRequest(token: entity.token);
  const RentalModelVerifyRequest({required super.token});

  Map<String, dynamic> toJson() {
    return {'token': token};
  }
}

class TenantRentalModelResponse extends TenantRentalResponse {
  const TenantRentalModelResponse({
    super.rentalId,
    required super.tenantId,
    required super.fullName,
    super.avatarUrl,
    required super.phoneNumber,
    required super.roomId,
    required super.roomName,
    required super.startDate,
    required super.status,
  });

  factory TenantRentalModelResponse.fromJson(Map<String, dynamic> json) {
    return TenantRentalModelResponse(
      rentalId: json['rental_id']?.toString(),
      tenantId: json['tenant_id']?.toString() ?? '',
      fullName: json['full_name'] ?? '',
      avatarUrl: json['avatar_url'],
      phoneNumber: json['phone_number'] ?? '',
      roomId: json['room_id']?.toString() ?? '',
      roomName: json['room_name'] ?? '',
      startDate: DateTime.parse(json['start_date']),
      status: json['status'] ?? '',
    );
  }
}

class RentalModelRoomResponse extends RentalRoomResponse {
  const RentalModelRoomResponse({
    required super.rentalId,
    required super.startDate,
    required super.roomId,
    required super.roomName,
    required super.roomThumbnail,
    required super.address,
    required super.price,
    required super.status,
  });

  factory RentalModelRoomResponse.fromJson(Map<String, dynamic> json) {
    return RentalModelRoomResponse(
      rentalId: json['rental_id']?.toString() ?? '',
      startDate: DateTime.parse(json['start_date']),
      roomId: json['room_id']?.toString() ?? '',
      roomName: json['room_name'] ?? '',
      roomThumbnail: json['room_thumbnail'] ?? '',
      address: json['address'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      status: json['status'] ?? '',
    );
  }
}

class RentalMessageModel {
  final String message;
  const RentalMessageModel({required this.message});

  factory RentalMessageModel.fromJson(Map<String, dynamic> json) =>
      RentalMessageModel(message: json['message'] as String);
}

class CurrentTenantsResponseModel {
  final List<TenantRentalModelResponse> data;
  const CurrentTenantsResponseModel({required this.data});
  factory CurrentTenantsResponseModel.fromJson(
    Map<String, dynamic> json,
  ) => CurrentTenantsResponseModel(
    data: (json['data'] as List<dynamic>)
        .map(
          (item) =>
              TenantRentalModelResponse.fromJson(item as Map<String, dynamic>),
        )
        .toList(),
  );
}

class MyRentedRoomsResponseModel {
  final List<RentalModelRoomResponse> data;
  const MyRentedRoomsResponseModel({required this.data});
  factory MyRentedRoomsResponseModel.fromJson(Map<String, dynamic> json) =>
      MyRentedRoomsResponseModel(
        data: (json['data'] as List<dynamic>)
            .map(
              (item) => RentalModelRoomResponse.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList(),
      );
}
