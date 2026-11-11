import 'dart:async';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/rental/domain/usecases/create_qr_code.dart';
import 'package:roomio/features/rental/domain/usecases/verify_qr_code.dart';
import 'package:roomio/features/rental/domain/usecases/destroy_relation.dart';
import 'package:roomio/features/rental/domain/usecases/get_my_tenants.dart';
import 'package:roomio/features/rental/domain/usecases/get_current_rent_room.dart';
import 'package:roomio/features/rental/presentation/bloc/remote/remote_rental_event.dart';
import 'package:roomio/features/rental/presentation/bloc/remote/remote_rental_state.dart';

class RemoteRentalBloc extends Bloc<RemoteRentalEvent, RemoteRentalState> {
  final CreateRentalQRCodeUseCase _createQRCode;
  final VerifyRentalQRCodeUseCase _verifyQRCode;
  final DestroyRentalRelationUseCase _destroyRelation;
  final GetMyTenantsUseCase _getMyTenants;
  final GetCurrentRentRoomUseCase _getCurrentRentRoom;
  final DateTime Function() _now;
  Timer? _timer;
  int _revision = 0;
  bool _mutating = false;

  RemoteRentalBloc(
    this._createQRCode,
    this._verifyQRCode,
    this._destroyRelation,
    this._getMyTenants,
    this._getCurrentRentRoom, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const RemoteRentalState()) {
    on<GetMyTenantsEvent>(getMyTenants);
    on<GetCurrentRentRoomEvent>(getCurrentRentRoom);
    on<CreateRentalQRCodeEvent>(createQRCode);
    on<VerifyRentalQRCodeEvent>(verifyQRCode);
    on<DestroyRentalRelationEvent>(destroyRelation);
    on<RentalQRCodeTickEvent>(tick);
  }

  Future<void> getMyTenants(
    GetMyTenantsEvent event,
    Emitter<RemoteRentalState> emit,
  ) async {
    if (_mutating) return;
    final revision = ++_revision;
    emit(
      state.copyWith(
        requestStatus: RemoteRentalStatus.loading,
        clearResult: true,
      ),
    );
    final result = await _getMyTenants(null);
    if (emit.isDone || revision != _revision) return;
    emit(
      result is DataSuccess
          ? state.copyWith(
              requestStatus: RemoteRentalStatus.loaded,
              tenants: result.data!,
            )
          : state.copyWith(
              requestStatus: RemoteRentalStatus.failure,
              dio: result.error!,
            ),
    );
  }

  Future<void> getCurrentRentRoom(
    GetCurrentRentRoomEvent event,
    Emitter<RemoteRentalState> emit,
  ) async {
    if (_mutating) return;
    final revision = ++_revision;
    emit(
      state.copyWith(
        requestStatus: RemoteRentalStatus.loading,
        clearResult: true,
      ),
    );
    final result = await _getCurrentRentRoom(null);
    if (emit.isDone || revision != _revision) return;
    emit(
      result is DataSuccess
          ? state.copyWith(
              requestStatus: RemoteRentalStatus.loaded,
              rooms: result.data!,
            )
          : state.copyWith(
              requestStatus: RemoteRentalStatus.failure,
              dio: result.error!,
            ),
    );
  }

  int _secondsLeft(DateTime expiresAt) =>
      max(0, (expiresAt.difference(_now()).inMilliseconds + 999) ~/ 1000);

  Future<void> createQRCode(
    CreateRentalQRCodeEvent event,
    Emitter<RemoteRentalState> emit,
  ) async {
    if (_mutating) return;
    _mutating = true;
    ++_revision;
    _timer?.cancel();
    final started = _now();
    emit(
      state.copyWith(
        requestStatus: RemoteRentalStatus.submitting,
        clearCode: true,
        clearResult: true,
      ),
    );
    try {
      final result = await _createQRCode(event.roomId);
      if (emit.isDone) return;
      if (result is DataSuccess) {
        // Do not extend the server's TTL by the time spent waiting for the network.
        final expiresAt = started.add(
          Duration(seconds: result.data!.expiresInSecond),
        );
        final seconds = _secondsLeft(expiresAt);
        emit(
          state.copyWith(
            requestStatus: RemoteRentalStatus.codeReady,
            qrCode: result.data!,
            qrExpiresAt: expiresAt,
            remainingSeconds: seconds,
          ),
        );
        if (seconds > 0) {
          _timer = Timer.periodic(const Duration(seconds: 1), (_) {
            if (!isClosed) add(const RentalQRCodeTickEvent());
          });
        }
      } else {
        emit(
          state.copyWith(
            requestStatus: RemoteRentalStatus.failure,
            dio: result.error!,
          ),
        );
      }
    } finally {
      _mutating = false;
    }
  }

  void tick(RentalQRCodeTickEvent event, Emitter<RemoteRentalState> emit) {
    final expiresAt = state.qrExpiresAt;
    if (expiresAt == null) return;
    final seconds = _secondsLeft(expiresAt);
    if (seconds == 0) _timer?.cancel();
    emit(state.copyWith(remainingSeconds: seconds));
  }

  Future<void> verifyQRCode(
    VerifyRentalQRCodeEvent event,
    Emitter<RemoteRentalState> emit,
  ) async {
    if (_mutating) return;
    _mutating = true;
    ++_revision;
    emit(
      state.copyWith(
        requestStatus: RemoteRentalStatus.submitting,
        clearResult: true,
      ),
    );
    try {
      final result = await _verifyQRCode(event.request);
      if (emit.isDone) return;
      emit(
        result is DataSuccess
            ? state.copyWith(
                requestStatus: RemoteRentalStatus.verified,
                verification: result.data!,
              )
            : state.copyWith(
                requestStatus: RemoteRentalStatus.failure,
                dio: result.error!,
              ),
      );
    } finally {
      _mutating = false;
    }
  }

  Future<void> destroyRelation(
    DestroyRentalRelationEvent event,
    Emitter<RemoteRentalState> emit,
  ) async {
    if (_mutating) return;
    _mutating = true;
    ++_revision;
    emit(
      state.copyWith(
        requestStatus: RemoteRentalStatus.submitting,
        clearResult: true,
      ),
    );
    try {
      final result = await _destroyRelation(event.rentalRelationId);
      if (emit.isDone) return;
      emit(
        result is DataSuccess
            ? state.copyWith(
                requestStatus: RemoteRentalStatus.ended,
                message: result.data!,
                tenants: state.tenants
                    ?.where(
                      (tenant) => tenant.rentalId != event.rentalRelationId,
                    )
                    .toList(),
                rooms: state.rooms
                    ?.where((room) => room.rentalId != event.rentalRelationId)
                    .toList(),
              )
            : state.copyWith(
                requestStatus: RemoteRentalStatus.failure,
                dio: result.error!,
              ),
      );
    } finally {
      _mutating = false;
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
