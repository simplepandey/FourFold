import 'package:equatable/equatable.dart';

class MotorSettingsModel extends Equatable {
  final double overCurrentThreshold;
  final double underCurrentThreshold;
  final double liveVoltage;
  final double ovTripVoltage;
  final double uvTripVoltage;
  final double liveCurrent;
  final bool dryRunProtection;
  final bool overflowProtection;
  final int maxRunTimeHours;

  const MotorSettingsModel({
    required this.overCurrentThreshold,
    required this.underCurrentThreshold,
    required this.liveVoltage,
    required this.ovTripVoltage,
    required this.uvTripVoltage,
    required this.liveCurrent,
    required this.dryRunProtection,
    required this.overflowProtection,
    required this.maxRunTimeHours,
  });

  static const MotorSettingsModel mock = MotorSettingsModel(
    overCurrentThreshold: 8.0,
    underCurrentThreshold: 0.5,
    liveVoltage: 232,
    ovTripVoltage: 260,
    uvTripVoltage: 180,
    liveCurrent: 4.2,
    dryRunProtection: true,
    overflowProtection: true,
    maxRunTimeHours: 2,
  );

  MotorSettingsModel copyWith({
    bool? dryRunProtection,
    bool? overflowProtection,
    double? overCurrentThreshold,
    double? underCurrentThreshold,
    int? maxRunTimeHours,
  }) =>
      MotorSettingsModel(
        overCurrentThreshold: overCurrentThreshold ?? this.overCurrentThreshold,
        underCurrentThreshold: underCurrentThreshold ?? this.underCurrentThreshold,
        liveVoltage: liveVoltage,
        ovTripVoltage: ovTripVoltage,
        uvTripVoltage: uvTripVoltage,
        liveCurrent: liveCurrent,
        dryRunProtection: dryRunProtection ?? this.dryRunProtection,
        overflowProtection: overflowProtection ?? this.overflowProtection,
        maxRunTimeHours: maxRunTimeHours ?? this.maxRunTimeHours,
      );

  @override
  List<Object?> get props => [
        overCurrentThreshold,
        underCurrentThreshold,
        dryRunProtection,
        overflowProtection,
        maxRunTimeHours,
      ];
}
