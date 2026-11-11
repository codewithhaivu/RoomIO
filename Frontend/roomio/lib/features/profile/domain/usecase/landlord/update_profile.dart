import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/profile/domain/entities/profile.dart';
import 'package:roomio/features/profile/domain/repository/profile_repository.dart';

class UpdateProfileLandLordUseCase extends UseCase<DataState<ProfileEntity>, ProfileEntity> {
  final ProfileRepository _profileLandlordRepository;

  UpdateProfileLandLordUseCase(this._profileLandlordRepository);

  @override
  Future<DataState<ProfileEntity>> call(ProfileEntity params) async {
      return await _profileLandlordRepository.updateProfile( params.name, params.gender, params.description, params.avartarUrl);
  }
}