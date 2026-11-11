


import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/auth/domain/entities/register.dart';
import 'package:roomio/features/auth/domain/repository/account_repository.dart';

class ResetPasswordUseCase implements UseCase<DataState<String>, ResetPasswordRequestEntity> {
  final AccountRepository _accountRepository;

  ResetPasswordUseCase(this._accountRepository);

  @override
  Future<DataState<String>> call(ResetPasswordRequestEntity request) {
    return _accountRepository.resetPassword(request.phoneNumber, request.newPassword);
  }
}