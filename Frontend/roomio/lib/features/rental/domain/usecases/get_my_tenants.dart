import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/rental/domain/entities/rental.dart';
import 'package:roomio/features/rental/domain/repository/rental_repository.dart';

class GetMyTenantsUseCase
    extends UseCase<DataState<List<TenantRentalResponse>>, void> {
  final RentalRepository _rentalRepository;
  GetMyTenantsUseCase(this._rentalRepository);
  @override
  Future<DataState<List<TenantRentalResponse>>> call(void params) async {
    return await _rentalRepository.getMyTenants();
  }
}
