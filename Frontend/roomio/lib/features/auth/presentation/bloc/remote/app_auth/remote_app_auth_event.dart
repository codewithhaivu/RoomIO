abstract class RemoteAppAuthEvent{
  const RemoteAppAuthEvent() ;
}

class CheckAuthStatusEvent extends RemoteAppAuthEvent {
  const CheckAuthStatusEvent();
}
class TokenExpiredEvent extends RemoteAppAuthEvent {
  const TokenExpiredEvent();
}
class LogoutEvent extends RemoteAppAuthEvent {
  final String token;
  const LogoutEvent({required this.token});
}
