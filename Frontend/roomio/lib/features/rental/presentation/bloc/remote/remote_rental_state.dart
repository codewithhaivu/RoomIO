import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:roomio/features/rental/domain/entities/rental.dart';

enum RemoteRentalStatus {
  initial,
  loading,
  loaded,
  submitting,
  codeReady,
  verified,
  ended,
  failure,
}

class RemoteRentalState extends Equatable {
  final RemoteRentalStatus requestStatus;
  final List<TenantRentalResponse>? tenants;
  final List<RentalRoomResponse>? rooms;
  final RentalResponse? qrCode;
  final DateTime? qrExpiresAt;
  final int remainingSeconds;
  final RentalVerifyResponse? verification;
  final String? message;
  final DioException? dio;

  const RemoteRentalState({
    this.requestStatus = RemoteRentalStatus.initial,
    this.tenants,
    this.rooms,
    this.qrCode,
    this.qrExpiresAt,
    this.remainingSeconds = 0,
    this.verification,
    this.message,
    this.dio,
  });
  bool get isBusy =>
      requestStatus == RemoteRentalStatus.loading ||
      requestStatus == RemoteRentalStatus.submitting;
  bool get hasActiveCode => qrCode != null && remainingSeconds > 0;

  RemoteRentalState copyWith({
    RemoteRentalStatus? requestStatus,
    List<TenantRentalResponse>? tenants,
    List<RentalRoomResponse>? rooms,
    RentalResponse? qrCode,
    DateTime? qrExpiresAt,
    int? remainingSeconds,
    RentalVerifyResponse? verification,
    String? message,
    DioException? dio,
    bool clearResult = false,
    bool clearCode = false,
  }) => RemoteRentalState(
    requestStatus: requestStatus ?? this.requestStatus,
    tenants: tenants == null ? this.tenants : List.unmodifiable(tenants),
    rooms: rooms == null ? this.rooms : List.unmodifiable(rooms),
    qrCode: clearCode ? null : qrCode ?? this.qrCode,
    qrExpiresAt: clearCode ? null : qrExpiresAt ?? this.qrExpiresAt,
    remainingSeconds: clearCode ? 0 : remainingSeconds ?? this.remainingSeconds,
    verification: verification ?? (clearResult ? null : this.verification),
    message: message ?? (clearResult ? null : this.message),
    dio: dio ?? (clearResult ? null : this.dio),
  );

  @override
  List<Object?> get props => [
    requestStatus,
    tenants,
    rooms,
    qrCode,
    qrExpiresAt,
    remainingSeconds,
    verification,
    message,
    dio,
  ];
}
