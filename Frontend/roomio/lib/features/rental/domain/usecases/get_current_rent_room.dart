import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/rental/domain/entities/rental.dart';
import 'package:roomio/features/rental/domain/repository/rental_repository.dart';

class GetCurrentRentRoomUseCase
    extends UseCase<DataState<List<RentalRoomResponse>>, void> {
  final RentalRepository _rentalRepository;
  GetCurrentRentRoomUseCase(this._rentalRepository);
  @override
  Future<DataState<List<RentalRoomResponse>>> call(void params) async {
    return await _rentalRepository.getCurrentRentRoom();
  }
}
