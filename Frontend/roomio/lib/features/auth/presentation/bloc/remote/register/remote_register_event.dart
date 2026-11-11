abstract class RemoteRegisterEvent{
  const RemoteRegisterEvent() ;
}

class Register extends RemoteRegisterEvent {
  final String phoneNumber;
  final String password;
  final String role ;

  const Register({required this.phoneNumber, required this.password, required this.role});
}

class SendOTPRegister extends RemoteRegisterEvent {
  final String phoneNumber;

  const SendOTPRegister({required this.phoneNumber});
}

class VerifyOTPRegister extends RemoteRegisterEvent {
  final String phoneNumber;
  final String otp;

  const VerifyOTPRegister({required this.phoneNumber, required this.otp});
}