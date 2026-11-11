import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/profile/domain/entities/profile.dart';
import 'package:roomio/features/profile/domain/repository/profile_repository.dart';

class UploadAvatarLandLordUseCase extends UseCase<DataState<ImageEntity>, String> {
  final ProfileRepository _profileLandlordRepository;

  UploadAvatarLandLordUseCase(this._profileLandlordRepository);

  @override
  Future<DataState<ImageEntity>> call(String avatarUrl) async {
      return await _profileLandlordRepository.uploadAvatar(avatarUrl);
  }
}