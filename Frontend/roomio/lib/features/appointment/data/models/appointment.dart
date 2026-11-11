import 'package:roomio/features/appointment/domain/entities/appointment.dart';

class AppointmentModelRequest extends AppointmentEntityRequest {
  const AppointmentModelRequest({required super.idRoom, required super.meetAt});
  factory AppointmentModelRequest.fromEntity(AppointmentEntityRequest entity) =>
      AppointmentModelRequest(idRoom: entity.idRoom, meetAt: entity.meetAt);

  Map<String, dynamic> toJson() {
    return {'id_room': idRoom, 'meet_at': meetAt.toUtc().toIso8601String()};
  }
}

class AppointmentModelResponse extends AppointmentEntityResponse {
  const AppointmentModelResponse({
    required super.idRoom,
    required super.meetAt,
    required super.idAppointment,
    required super.nameRoom,
    required super.nameTenant,
    super.status,
  });
  factory AppointmentModelResponse.fromJson(Map<String, dynamic> json) {
    final value = json['meet_at'] as String;
    // Backend stores naive datetimes in Vietnam time (UTC+7).
    final hasTimezone = RegExp(
      r'(Z|[+-]\d{2}:?\d{2})$',
      caseSensitive: false,
    ).hasMatch(value);
    return AppointmentModelResponse(
      idRoom: json['id_room'] as String,
      meetAt: DateTime.parse(hasTimezone ? value : '$value+07:00').toUtc(),
      idAppointment: json['id_appointment'] as String,
      nameRoom: json['name_room'] as String,
      nameTenant: json['name_tenant'] as String,
      status: json['status'] as String? ?? 'PENDING',
    );
  }
}

class ListAppointmentResponseModel {
  final List<AppointmentModelResponse> data;
  const ListAppointmentResponseModel({required this.data});

  factory ListAppointmentResponseModel.fromJson(Map<String, dynamic> json) =>
      ListAppointmentResponseModel(
        data: (json['data'] as List<dynamic>)
            .map(
              (item) => AppointmentModelResponse.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList(),
      );
}

class AppointmentMessageModel {
  final String message;
  const AppointmentMessageModel({required this.message});

  factory AppointmentMessageModel.fromJson(Map<String, dynamic> json) =>
      AppointmentMessageModel(message: json['message'] as String);
}
