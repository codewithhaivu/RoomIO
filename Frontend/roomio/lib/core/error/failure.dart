import 'package:equatable/equatable.dart';

class Failure extends Equatable {
  final String message;
  final bool connectionLost;
  const Failure(this.message, {this.connectionLost = false});
  @override
  List<Object?> get props => [message, connectionLost];
}
