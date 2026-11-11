


import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/auth/domain/entities/register.dart';
import 'package:roomio/features/auth/domain/repository/account_repository.dart';

class RegisterUseCase implements UseCase<DataState<String>, RegisterRequestEntity> {
  final AccountRepository _accountRepository;

  RegisterUseCase(this._accountRepository);

  @override
  Future<DataState<String>> call(RegisterRequestEntity request) {
    return _accountRepository.register(request.phoneNumber, request.password, request.role);
  }
}