import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/storage/secure_storage_service.dart';
import 'package:roomio/features/auth/domain/usecase/logout.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/app_auth/remote_app_auth_event.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/app_auth/remote_app_auth_state.dart';
import 'package:roomio/features/notification/application/notification_device_sync.dart';

class RemoteAppAuthBloc extends Bloc<RemoteAppAuthEvent, RemoteAppAuthState> {
  final LogoutUseCase _logoutUseCase;
  final SecureStorageService _secureStorage;
  final NotificationDeviceSync _devices;

  RemoteAppAuthBloc(this._logoutUseCase, this._secureStorage, this._devices)
    : super(const RemoteAppAuthInitial()) {
    on<CheckAuthStatusEvent>(checkAuthStatus);
    on<LogoutEvent>(logout);
    on<TokenExpiredEvent>((event, emit) async {
      emit(const AppUnauthenticated());
    });
  }

  // 3. Logic xử lý khi mở app
  void checkAuthStatus(
    CheckAuthStatusEvent event,
    Emitter<RemoteAppAuthState> emit,
  ) async {
    emit(const RemoteAppAuthLoading());

    final token = await _secureStorage.getAccessToken();

    if (token != null && token.isNotEmpty) {
      _devices.startSession(token);
      emit(const AppAuthenticated());
    } else {
      emit(const AppUnauthenticated());
    }
  }

  void logout(LogoutEvent event, Emitter<RemoteAppAuthState> emit) async {
    emit(const RemoteAppAuthLoading());
    await _devices.unregisterSession();
    final dataState = await _logoutUseCase(event.token);

    if (dataState is DataSuccess) {
      await _secureStorage.clearAll();
      emit(const AppUnauthenticated());
    } else {
      emit(RemoteAppAuthErrorState(error: dataState.error!));
    }
  }
}
