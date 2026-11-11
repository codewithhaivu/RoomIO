abstract class RemoteForgotPasswordEvent{
  const RemoteForgotPasswordEvent() ;
}

class SendOTPForgotPassword extends RemoteForgotPasswordEvent {
  final String phoneNumber;

  const SendOTPForgotPassword({required this.phoneNumber});
}

class VerifyOTPForgotPassword extends RemoteForgotPasswordEvent {
  final String phoneNumber;
  final String otp;

  const VerifyOTPForgotPassword({required this.phoneNumber, required this.otp});
}

class ResetPassword extends RemoteForgotPasswordEvent {
  final String phoneNumber;
  final String newPassword;

  const ResetPassword({required this.phoneNumber, required this.newPassword});
}
