
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/auth/domain/repository/account_repository.dart';

class CheckPhoneUseCase implements UseCase<DataState<bool>, String> {
  final AccountRepository _accountRepository;

  CheckPhoneUseCase(this._accountRepository);

  @override
  Future<DataState<bool>> call(String? params)  {
    return  _accountRepository.checkPhoneExists(params!);
  }
}