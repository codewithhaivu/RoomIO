


import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/auth/domain/repository/account_repository.dart';

class LogoutUseCase implements UseCase<DataState<String>, String> {
  final AccountRepository _accountRepository;

  LogoutUseCase(this._accountRepository);

  @override
  Future<DataState<String>> call(String refreshToken) {
    return _accountRepository.logout(refreshToken);
  }
}