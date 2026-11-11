import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/auth/domain/repository/account_repository.dart';

class GetNewTokenUseCase implements UseCase<DataState<String>, String> {
  final AccountRepository _accountRepository;

  GetNewTokenUseCase(this._accountRepository);

  @override
  Future<DataState<String>> call(String refreshToken) {
    return _accountRepository.refreshToken(refreshToken);
  }
}