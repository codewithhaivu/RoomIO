import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/profile/domain/entities/profile.dart';
import 'package:roomio/features/profile/domain/repository/profile_repository.dart';

class CreateProfileLandLordUseCase extends UseCase<DataState<ProfileEntity>, ProfileEntity> {
  final ProfileRepository _profileLandlordRepository;

  CreateProfileLandLordUseCase(this._profileLandlordRepository);

  @override
  Future<DataState<ProfileEntity>> call(ProfileEntity params) async {
      return await _profileLandlordRepository.createProfile(params.name! , params.gender! , params.description! , params.avartarUrl!);
  }
}