import 'package:equatable/equatable.dart';
import 'pump_status_model.dart';

/// Mirrors the backend `module_status` table — GET /module-status/:productCode
class ModuleStatusModel extends Equatable {
  final String productCode;
  final double voltage;
  final double current;
  final double overcurrent;
  final double undercurrent;
  final int overheadTankLevel;
  final int undergroundTankLevel;
  final String motorStatus; // 'ON' | 'OFF'
  final bool ocBreached;
  final bool ucBreached;
  final bool isOnline;
  final DateTime? updatedAt;
  final String? updatedBy;

  const ModuleStatusModel({
    required this.productCode,
    required this.voltage,
    required this.current,
    required this.overcurrent,
    required this.undercurrent,
    required this.overheadTankLevel,
    required this.undergroundTankLevel,
    required this.motorStatus,
    required this.ocBreached,
    required this.ucBreached,
    this.isOnline = false,
    this.updatedAt,
    this.updatedBy,
  });

  bool get isOn => motorStatus == 'ON';

  factory ModuleStatusModel.fromJson(Map<String, dynamic> json) =>
      ModuleStatusModel(
        productCode: (json['productCode'] as String?) ?? '',
        voltage: (json['voltage'] as num?)?.toDouble() ?? 0,
        current: (json['current'] as num?)?.toDouble() ?? 0,
        overcurrent: (json['overcurrent'] as num?)?.toDouble() ?? 0,
        undercurrent: (json['undercurrent'] as num?)?.toDouble() ?? 0,
        overheadTankLevel: (json['overheadTankLevel'] as num?)?.toInt() ?? 0,
        undergroundTankLevel:
            (json['undergroundTankLevel'] as num?)?.toInt() ?? 0,
        motorStatus: (json['motorStatus'] as String?) ?? 'OFF',
        ocBreached: (json['ocBreached'] as bool?) ?? false,
        ucBreached: (json['ucBreached'] as bool?) ?? false,
        isOnline: (json['isOnline'] as bool?) ?? false,
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'] as String)
            : null,
        updatedBy: json['updatedBy'] as String?,
      );

  /// Adapts to the model the existing pump UI (VoltageCurrentCard / PumpControlCard) already renders.
  PumpStatusModel toPumpStatus({required String pumpName}) => PumpStatusModel(
        pumpId: productCode,
        pumpName: pumpName,
        motorStatus: isOn ? MotorStatus.on : MotorStatus.off,
        mode: MotorMode.manual,
        overheadPercent: overheadTankLevel.clamp(0, 100) / 100,
        undergroundPercent: undergroundTankLevel.clamp(0, 100) / 100,
        voltage: voltage,
        current: current,
        isOnline: isOnline,
        ocBreached: ocBreached,
        ucBreached: ucBreached,
        overcurrent: overcurrent,
        undercurrent: undercurrent,
      );

  static ModuleStatusModel mock(String productCode) => ModuleStatusModel(
        productCode: productCode,
        voltage: 232,
        current: 4.2,
        overcurrent: 8,
        undercurrent: 1,
        overheadTankLevel: 68,
        undergroundTankLevel: 45,
        motorStatus: 'ON',
        ocBreached: false,
        ucBreached: false,
        isOnline: true,
      );

  @override
  List<Object?> get props => [
        productCode,
        voltage,
        current,
        motorStatus,
        overheadTankLevel,
        undergroundTankLevel
      ];
}
