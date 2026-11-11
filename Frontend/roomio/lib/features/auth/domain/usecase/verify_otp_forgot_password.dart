


import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/auth/domain/entities/register.dart';
import 'package:roomio/features/auth/domain/repository/account_repository.dart';

class VerifyOTPForgotPasswordUseCase implements UseCase<DataState<bool>, VerifyOTPRequestEntity> {
  final AccountRepository _accountRepository;

  VerifyOTPForgotPasswordUseCase(this._accountRepository);

  @override
  Future<DataState<bool>> call(VerifyOTPRequestEntity request) {
    return _accountRepository.verifyOTP(request.phoneNumber, request.otp);
  }
}