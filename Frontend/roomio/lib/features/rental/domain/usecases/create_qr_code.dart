import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/rental/domain/entities/rental.dart';
import 'package:roomio/features/rental/domain/repository/rental_repository.dart';

class CreateRentalQRCodeUseCase
    extends UseCase<DataState<RentalResponse>, String> {
  final RentalRepository _rentalRepository;
  CreateRentalQRCodeUseCase(this._rentalRepository);
  @override
  Future<DataState<RentalResponse>> call(String params) async {
    return await _rentalRepository.createQRCode(params);
  }
}
