import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/storage/secure_storage_service.dart';
import 'package:roomio/features/auth/domain/entities/login.dart';
import 'package:roomio/features/auth/domain/usecase/check_phone.dart';
import 'package:roomio/features/auth/domain/usecase/login.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/login/remote_login_event.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/login/remote_login_state.dart';
import 'package:roomio/features/notification/application/notification_device_sync.dart';

class RemoteLoginBloc extends Bloc<RemoteLoginEvent, RemoteLoginState> {
  final LoginUseCase _remoteLoginUseCase;
  final CheckPhoneUseCase _checkPhoneNumberUseCase;
  final SecureStorageService _secureStorage;
  final NotificationDeviceSync _devices;

  RemoteLoginBloc(
    this._remoteLoginUseCase,
    this._checkPhoneNumberUseCase,
    this._secureStorage,
    this._devices,
  ) : super(const RemoteLoginInitial()) {
    on<Login>(login);
    on<CheckPhoneNumberEvent>(checkPhoneNumber);
  }

  void login(Login event, Emitter<RemoteLoginState> emit) async {
    emit(const RemoteLoginLoading());
    final dataState = await _remoteLoginUseCase(
      LoginRequestEntity(
        phoneNumber: event.phoneNumber,
        password: event.password,
      ),
    );
    if (dataState is DataSuccess) {
      await _secureStorage.saveTokens(
        accessToken: dataState.data!.accessToken,
        rfToken: dataState.data!.rfToken,
        role: dataState.data!.role,
      );
      _devices.startSession(dataState.data!.accessToken);
      emit(RemoteLoginSuccess(loginResponseEntity: dataState.data!));
    } else {
      emit(RemoteLoginFailure(dioException: dataState.error!));
    }
  }

  void checkPhoneNumber(
    CheckPhoneNumberEvent event,
    Emitter<RemoteLoginState> emit,
  ) async {
    emit(const RemoteLoginLoading());
    final dataState = await _checkPhoneNumberUseCase(event.phoneNumber);
    if (dataState is DataSuccess) {
      emit(CheckPhoneNumberSuccessState(isExist: dataState.data!));
    } else {
      emit(RemoteLoginFailure(dioException: dataState.error!));
    }
  }
}
