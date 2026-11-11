import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/auth/domain/entities/register.dart';
import 'package:roomio/features/auth/domain/usecase/reset_password.dart';
import 'package:roomio/features/auth/domain/usecase/send_otp_forgot_password.dart';
import 'package:roomio/features/auth/domain/usecase/verify_otp_forgot_password.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/forgot_password/remote_forgot_password_event.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/forgot_password/remote_forgot_password_state.dart';


class RemoteForgotPasswordBloc extends Bloc<RemoteForgotPasswordEvent, RemoteForgotPasswordState> {
  final SendOTPForgotPasswordUseCase _sendOTPForgotPasswordUseCase;
  final VerifyOTPForgotPasswordUseCase _verifyOTPForgotPasswordUseCase;
  final ResetPasswordUseCase _resetPasswordUseCase;

  RemoteForgotPasswordBloc(this._sendOTPForgotPasswordUseCase, this._verifyOTPForgotPasswordUseCase, this._resetPasswordUseCase)
    : super(const RemoteForgotPasswordInitial()) {
    on<SendOTPForgotPassword>(sendOTPForgotPassword);
    on<VerifyOTPForgotPassword>(verifyOTPForgotPassword);
    on<ResetPassword>(resetPassword);
  }

  void sendOTPForgotPassword(SendOTPForgotPassword event, Emitter<RemoteForgotPasswordState> emit) async {
    emit(const RemoteForgotPasswordLoading());
    final dataState = await _sendOTPForgotPasswordUseCase(event.phoneNumber);
    if (dataState is DataSuccess) {
      emit(sendOTPForgotPasswordSuccessState(otp: dataState.data));
    } else {
      emit(RemoteForgotPasswordFailure(dioException: dataState.error!));
    }
  }
  void verifyOTPForgotPassword(VerifyOTPForgotPassword event, Emitter<RemoteForgotPasswordState> emit) async {
    emit(const RemoteForgotPasswordLoading());
    final dataState = await _verifyOTPForgotPasswordUseCase(
      VerifyOTPRequestEntity(
        phoneNumber: event.phoneNumber,
        otp: event.otp,
      ),
    );
    if (dataState is DataSuccess) {
      emit(verifyOTPForgotPasswordSuccessState(isVerified: dataState.data));
    } else {
      emit(RemoteForgotPasswordFailure(dioException: dataState.error!));
    }
  }

  void resetPassword(ResetPassword event, Emitter<RemoteForgotPasswordState> emit) async {
    emit(const RemoteForgotPasswordLoading());
    final dataState = await _resetPasswordUseCase(
      ResetPasswordRequestEntity(
        phoneNumber: event.phoneNumber,
        newPassword: event.newPassword,
      ),
    );
    if (dataState is DataSuccess) {
      emit(ResetPasswordSuccessState(message: dataState.data));
    } else {
      emit(RemoteForgotPasswordFailure(dioException: dataState.error!));
    }
  }
}
