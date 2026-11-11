import 'package:equatable/equatable.dart';
import 'package:roomio/features/rental/domain/entities/rental.dart';

abstract class RemoteRentalEvent extends Equatable {
  const RemoteRentalEvent();
  @override
  List<Object?> get props => [];
}

class GetMyTenantsEvent extends RemoteRentalEvent {
  const GetMyTenantsEvent();
}

class GetCurrentRentRoomEvent extends RemoteRentalEvent {
  const GetCurrentRentRoomEvent();
}

class CreateRentalQRCodeEvent extends RemoteRentalEvent {
  final String roomId;
  const CreateRentalQRCodeEvent({required this.roomId});
  @override
  List<Object?> get props => [roomId];
}

class VerifyRentalQRCodeEvent extends RemoteRentalEvent {
  final RentalVerifyRequest request;
  const VerifyRentalQRCodeEvent({required this.request});
  @override
  List<Object?> get props => [request];
}

class DestroyRentalRelationEvent extends RemoteRentalEvent {
  final String rentalRelationId;
  const DestroyRentalRelationEvent({required this.rentalRelationId});
  @override
  List<Object?> get props => [rentalRelationId];
}

class RentalQRCodeTickEvent extends RemoteRentalEvent {
  const RentalQRCodeTickEvent();
}
