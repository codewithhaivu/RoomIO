import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/auth/domain/entities/register.dart';
import 'package:roomio/features/auth/domain/usecase/register.dart';
import 'package:roomio/features/auth/domain/usecase/send_otp_register.dart';
import 'package:roomio/features/auth/domain/usecase/verify_otp_register.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/register/remote_register_event.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/register/remote_register_state.dart';


class RemoteRegisterBloc extends Bloc<RemoteRegisterEvent, RemoteRegisterState> {
  final RegisterUseCase _remoteRegisterUseCase;
  final SendOTPRegisterUseCase _sendOTPRegisterUseCase;
  final VerifyOTPRegisterUseCase _verifyOTPRegisterUseCase;

  RemoteRegisterBloc(this._remoteRegisterUseCase, this._sendOTPRegisterUseCase, this._verifyOTPRegisterUseCase)
    : super(const RemoteRegisterInitial()) {
    on<Register>(register);
    on<SendOTPRegister>(sendOTPRegister);
    on<VerifyOTPRegister>(verifyOTPRegister);
  }

  void register(Register event, Emitter<RemoteRegisterState> emit) async {
    emit(const RemoteRegisterLoading());
    final dataState = await _remoteRegisterUseCase(
      RegisterRequestEntity(
        phoneNumber: event.phoneNumber,
        password: event.password,
        role: event.role,
      ),
    );
    if (dataState is DataSuccess) {
      emit(RemoteRegisterSuccessState(message: dataState.data!));
    } else {
      emit(RemoteRegisterFailure(dioException: dataState.error!));
    }
  }
  void sendOTPRegister(SendOTPRegister event, Emitter<RemoteRegisterState> emit) async {
    emit(const RemoteRegisterLoading());
    final dataState = await _sendOTPRegisterUseCase(event.phoneNumber);
    if (dataState is DataSuccess) {
      emit(SendOTPSuccessState(otp: dataState.data!));
    } else {
      emit(RemoteRegisterFailure(dioException: dataState.error!));
    }
  }
  void verifyOTPRegister(VerifyOTPRegister event, Emitter<RemoteRegisterState> emit) async {
    emit(const RemoteRegisterLoading());
    final dataState = await _verifyOTPRegisterUseCase(
      VerifyOTPRequestEntity(
        phoneNumber: event.phoneNumber,
        otp: event.otp,
      ),
    );
    if (dataState is DataSuccess) {
      emit(VerifyOTPSuccessState(isVerified: dataState.data!));
    } else {
      emit(RemoteRegisterFailure(dioException: dataState.error!));
    }
  }
}
