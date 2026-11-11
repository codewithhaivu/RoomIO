import 'package:equatable/equatable.dart';

class RentalResponse extends Equatable {
  final String qrToken;
  final int expiresInSecond;

  const RentalResponse({required this.qrToken, required this.expiresInSecond});

  @override
  List<Object?> get props => [qrToken, expiresInSecond];
}

class RentalVerifyResponse extends Equatable {
  final String message;
  final bool isValid;

  const RentalVerifyResponse({required this.message, required this.isValid});

  @override
  List<Object?> get props => [message, isValid];
}

class RentalVerifyRequest extends Equatable {
  final String token;

  const RentalVerifyRequest({required this.token});

  @override
  List<Object?> get props => [token];
}

class TenantRentalResponse extends Equatable {
  final String? rentalId;
  final String tenantId;
  final String fullName;
  final String? avatarUrl; // Biến này có thể null
  final String phoneNumber;
  final String roomId;
  final String roomName;
  final DateTime startDate;
  final String status;

  const TenantRentalResponse({
    this.rentalId,
    required this.tenantId,
    required this.fullName,
    this.avatarUrl,
    required this.phoneNumber,
    required this.roomId,
    required this.roomName,
    required this.startDate,
    required this.status,
  });

  @override
  List<Object?> get props => [
    rentalId,
    tenantId,
    fullName,
    avatarUrl,
    phoneNumber,
    roomId,
    roomName,
    startDate,
    status,
  ];
}

class RentalRoomResponse extends Equatable {
  final String rentalId;
  final DateTime startDate;
  final String status;
  final String roomId;
  final String roomName;
  final String roomThumbnail;
  final String address;
  final double price;

  const RentalRoomResponse({
    required this.rentalId,
    required this.startDate,
    required this.roomId,
    required this.roomName,
    required this.roomThumbnail,
    required this.address,
    required this.price,
    required this.status,
  });

  @override
  List<Object?> get props => [
    rentalId,
    startDate,
    status,
    roomId,
    roomName,
    roomThumbnail,
    address,
    price,
  ];
}
