import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/profile/domain/entities/profile.dart';
import 'package:roomio/features/profile/domain/repository/profile_repository.dart';

class CreateProfileTenantUseCase extends UseCase<DataState<ProfileEntity>, ProfileEntity> {
  final ProfileRepository _profileTenantRepository;

  CreateProfileTenantUseCase(this._profileTenantRepository);

  @override
  Future<DataState<ProfileEntity>> call(ProfileEntity params) async {
      return await _profileTenantRepository.createProfile(params.name! , params.gender! , params.description! , params.avartarUrl!);
  }
}