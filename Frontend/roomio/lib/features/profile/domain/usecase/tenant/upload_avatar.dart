import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/profile/domain/entities/profile.dart';
import 'package:roomio/features/profile/domain/repository/profile_repository.dart';

class UploadAvatarTenantUseCase extends UseCase<DataState<ImageEntity>, String> {
  final ProfileRepository _profileTenantRepository;

  UploadAvatarTenantUseCase(this._profileTenantRepository);

  @override
  Future<DataState<ImageEntity>> call(String avatarUrl) async {
      return await _profileTenantRepository.uploadAvatar(avatarUrl);
  }
}