import 'package:equatable/equatable.dart';

enum MotorMode { manual, auto, schedule }

enum MotorStatus { on, off, fault, unknown }

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
  final bool ocBreached;
  final bool ucBreached;
  final double overcurrent; // configured overcurrent threshold (A)
  final double undercurrent; // configured undercurrent threshold (A)

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
    this.ocBreached = false,
    this.ucBreached = false,
    this.overcurrent = 0,
    this.undercurrent = 0,
  });

  bool get hasActiveAlert => ocBreached || ucBreached;

  PumpStatusModel copyWith({
    MotorStatus? motorStatus,
    MotorMode? mode,
    double? overheadPercent,
    double? undergroundPercent,
    double? voltage,
    double? current,
    bool? ocBreached,
    bool? ucBreached,
    double? overcurrent,
    double? undercurrent,
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
        ocBreached: ocBreached ?? this.ocBreached,
        ucBreached: ucBreached ?? this.ucBreached,
        overcurrent: overcurrent ?? this.overcurrent,
        undercurrent: undercurrent ?? this.undercurrent,
      );

  /// Placeholder when no status data is available yet — zero readings, motor state unknown (neither ON/OFF button selected).
  static PumpStatusModel empty(String pumpId) => PumpStatusModel(
        pumpId: pumpId,
        pumpName: 'Main Pump',
        motorStatus: MotorStatus.unknown,
        mode: MotorMode.manual,
        overheadPercent: 0,
        undergroundPercent: 0,
        voltage: 0,
        current: 0,
        isOnline: false,
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
        overcurrent: 8,
        undercurrent: 1,
      );

  @override
  List<Object?> get props => [
        pumpId,
        motorStatus,
        mode,
        overheadPercent,
        undergroundPercent,
        ocBreached,
        ucBreached,
      ];
}
