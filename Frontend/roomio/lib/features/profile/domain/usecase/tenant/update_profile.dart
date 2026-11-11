import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/profile/domain/entities/profile.dart';
import 'package:roomio/features/profile/domain/repository/profile_repository.dart';

class UpdateProfileTenantUseCase extends UseCase<DataState<ProfileEntity>, ProfileEntity> {
  final ProfileRepository _profileTenantRepository;

  UpdateProfileTenantUseCase(this._profileTenantRepository);

  @override
  Future<DataState<ProfileEntity>> call(ProfileEntity params) async {
      return await _profileTenantRepository.updateProfile( params.name, params.gender, params.description, params.avartarUrl);
  }
}