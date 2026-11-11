import 'package:equatable/equatable.dart';

class AppointmentEntityRequest extends Equatable {
  final String idRoom;
  final DateTime meetAt;

  const AppointmentEntityRequest({required this.idRoom, required this.meetAt});

  @override
  List<Object?> get props => [idRoom, meetAt];
}

class AppointmentEntityResponse extends Equatable {
  final String idRoom;
  final DateTime meetAt;
  final String idAppointment;
  final String nameRoom;
  final String nameTenant;
  final String status;

  const AppointmentEntityResponse({
    required this.idRoom,
    required this.meetAt,
    required this.idAppointment,
    required this.nameRoom,
    required this.nameTenant,
    this.status = 'PENDING',
  });

  AppointmentEntityResponse copyWith({DateTime? meetAt, String? status}) =>
      AppointmentEntityResponse(
        idRoom: idRoom,
        meetAt: meetAt ?? this.meetAt,
        idAppointment: idAppointment,
        nameRoom: nameRoom,
        nameTenant: nameTenant,
        status: status ?? this.status,
      );

  @override
  List<Object?> get props => [
    idRoom,
    meetAt,
    idAppointment,
    nameRoom,
    nameTenant,
    status,
  ];
}
