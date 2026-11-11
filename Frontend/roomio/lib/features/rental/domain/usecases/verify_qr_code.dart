import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/rental/domain/entities/rental.dart';
import 'package:roomio/features/rental/domain/repository/rental_repository.dart';

class VerifyRentalQRCodeUseCase
    extends UseCase<DataState<RentalVerifyResponse>, RentalVerifyRequest> {
  final RentalRepository _rentalRepository;
  VerifyRentalQRCodeUseCase(this._rentalRepository);
  @override
  Future<DataState<RentalVerifyResponse>> call(
    RentalVerifyRequest params,
  ) async {
    return await _rentalRepository.verifyQRCode(params);
  }
}
