import 'package:equatable/equatable.dart';
import '../../data/models/pump_status_model.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();
  @override
  List<Object?> get props => [];
}

class LoadHomeData extends HomeEvent {
  const LoadHomeData();
}

class RefreshStatus extends HomeEvent {
  const RefreshStatus();
}

class ToggleMotor extends HomeEvent {
  final bool turnOn;
  const ToggleMotor(this.turnOn);
  @override
  List<Object?> get props => [turnOn];
}

class ChangeMotorMode extends HomeEvent {
  final MotorMode mode;
  const ChangeMotorMode(this.mode);
  @override
  List<Object?> get props => [mode];
}
