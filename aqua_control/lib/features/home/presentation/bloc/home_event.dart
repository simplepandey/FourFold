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
  // true for a user-initiated pull-to-refresh — bypasses the in-flight
  // guard in HomeBloc so it never gets silently dropped just because the
  // background poll timer's own fetch (which can itself take up to 30s)
  // happens to still be running. false for the automatic poll tick, which
  // should keep skipping itself while one is already in flight.
  final bool force;
  const RefreshStatus({this.force = false});
  @override
  List<Object?> get props => [force];
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
