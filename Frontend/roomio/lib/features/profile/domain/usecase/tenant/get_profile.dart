import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/profile/domain/entities/profile.dart';
import 'package:roomio/features/profile/domain/repository/profile_repository.dart';

class GetProfileTenantUseCase extends UseCase<DataState<ProfileEntity>, void> {
  final ProfileRepository _profileTenantRepository;

  GetProfileTenantUseCase(this._profileTenantRepository);

  @override
  Future<DataState<ProfileEntity>> call(void params) async {
      return await _profileTenantRepository.getProfile();
  }
}