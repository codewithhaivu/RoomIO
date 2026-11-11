


import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/auth/domain/entities/login.dart';
import 'package:roomio/features/auth/domain/repository/account_repository.dart';

class LoginUseCase implements UseCase<DataState<LoginResponseEntity>, LoginRequestEntity> {
  final AccountRepository _accountRepository;

  LoginUseCase(this._accountRepository);

  @override
  Future<DataState<LoginResponseEntity>> call(LoginRequestEntity request) {
    return _accountRepository.login(request.phoneNumber, request.password);
  }
}