import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/rental/domain/entities/rental.dart';

abstract class RentalRepository {
  Future<DataState<RentalResponse>> createQRCode(String roomId);
  Future<DataState<RentalVerifyResponse>> verifyQRCode(
    RentalVerifyRequest request,
  );
  Future<DataState<String>> destroyRelation(String rentalRelationId);
  Future<DataState<List<TenantRentalResponse>>> getMyTenants();
  Future<DataState<List<RentalRoomResponse>>> getCurrentRentRoom();
}
