import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/rental/domain/repository/rental_repository.dart';

class DestroyRentalRelationUseCase extends UseCase<DataState<String>, String> {
  final RentalRepository _rentalRepository;
  DestroyRentalRelationUseCase(this._rentalRepository);
  @override
  Future<DataState<String>> call(String params) async {
    return await _rentalRepository.destroyRelation(params);
  }
}
