abstract class RemoteLoginEvent{
  const RemoteLoginEvent() ;
}

class Login extends RemoteLoginEvent {
  final String phoneNumber;
  final String password;

  const Login({required this.phoneNumber, required this.password});
}
class CheckPhoneNumberEvent extends RemoteLoginEvent {
  final String phoneNumber;
  const CheckPhoneNumberEvent({required this.phoneNumber});
}