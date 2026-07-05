import 'package:equatable/equatable.dart';

enum MotorMode { manual, auto, schedule }

enum MotorStatus { on, off, fault }

class PumpStatusModel extends Equatable {
  final String pumpId;
  final String pumpName;
  final MotorStatus motorStatus;
  final MotorMode mode;
  final double overheadPercent; // 0.0 – 1.0
  final double undergroundPercent;
  final double voltage;
  final double current;
  final bool isOnline;

  const PumpStatusModel({
    required this.pumpId,
    required this.pumpName,
    required this.motorStatus,
    required this.mode,
    required this.overheadPercent,
    required this.undergroundPercent,
    required this.voltage,
    required this.current,
    required this.isOnline,
  });

  PumpStatusModel copyWith({
    MotorStatus? motorStatus,
    MotorMode? mode,
    double? overheadPercent,
    double? undergroundPercent,
    double? voltage,
    double? current,
  }) =>
      PumpStatusModel(
        pumpId: pumpId,
        pumpName: pumpName,
        motorStatus: motorStatus ?? this.motorStatus,
        mode: mode ?? this.mode,
        overheadPercent: overheadPercent ?? this.overheadPercent,
        undergroundPercent: undergroundPercent ?? this.undergroundPercent,
        voltage: voltage ?? this.voltage,
        current: current ?? this.current,
        isOnline: isOnline,
      );

  static PumpStatusModel get mock => const PumpStatusModel(
        pumpId: 'PAD_dc9854f924f0',
        pumpName: 'Main Pump',
        motorStatus: MotorStatus.on,
        mode: MotorMode.auto,
        overheadPercent: 0.68,
        undergroundPercent: 0.45,
        voltage: 232,
        current: 4.2,
        isOnline: true,
      );

  @override
  List<Object?> get props => [pumpId, motorStatus, mode, overheadPercent, undergroundPercent];
}
