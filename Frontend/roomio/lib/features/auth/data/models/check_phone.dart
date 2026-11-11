

class CheckPhoneRequestModel {
  final String phoneNumber;

  CheckPhoneRequestModel({required this.phoneNumber});

  Map<String, dynamic> toJson() {
    return {
      'phone_number': phoneNumber,
    };
  }
}

class CheckPhoneResponseModel {
  final bool exists;

  CheckPhoneResponseModel({required this.exists});

  factory CheckPhoneResponseModel.fromJson(Map<String, dynamic> json) {
    return CheckPhoneResponseModel(
      exists: json['exist'],
    );
  }
}