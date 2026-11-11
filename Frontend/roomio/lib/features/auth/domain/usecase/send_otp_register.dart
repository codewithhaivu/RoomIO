


import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/auth/domain/repository/account_repository.dart';

class SendOTPRegisterUseCase implements UseCase<DataState<String>, String> {
  final AccountRepository _accountRepository;

  SendOTPRegisterUseCase(this._accountRepository);

  @override
  Future<DataState<String>> call(String phoneNumber) {
    return _accountRepository.sendOTP(phoneNumber);
  }
}