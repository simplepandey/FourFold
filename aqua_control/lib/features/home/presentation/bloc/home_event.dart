import 'package:equatable/equatable.dart';
import '../../data/models/pump_status_model.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();
  @override
  List<Object?> get props => [];
}

class LoadHomeData extends HomeEvent {
  final String userName;
  final String productCode;
  final String societyCode;
  final String commandBy;
  const LoadHomeData({
    this.userName = '',
    this.productCode = '',
    this.societyCode = '',
    this.commandBy = '',
  });
  @override
  List<Object?> get props => [userName, productCode, societyCode, commandBy];
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

class SetThresholds extends HomeEvent {
  final double overcurrent;
  final double undercurrent;
  const SetThresholds({required this.overcurrent, required this.undercurrent});
  @override
  List<Object?> get props => [overcurrent, undercurrent];
}
