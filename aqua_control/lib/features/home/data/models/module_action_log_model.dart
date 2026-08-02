import 'package:equatable/equatable.dart';

/// Mirrors a row of the backend `module_action_logs` table — GET /module-action-logs/:serialNumber
class ModuleActionLogModel extends Equatable {
  final String id;
  final String serialNumber;
  final double voltage;
  final double current;
  final double overcurrent;
  final double undercurrent;
  final int overheadTankLevel;
  final int undergroundTankLevel;
  final String motorStatus; // 'ON' | 'OFF'
  final bool ocBreached;
  final bool ucBreached;
  final DateTime? createdAt;
  final String? createdBy;

  const ModuleActionLogModel({
    required this.id,
    required this.serialNumber,
    required this.voltage,
    required this.current,
    required this.overcurrent,
    required this.undercurrent,
    required this.overheadTankLevel,
    required this.undergroundTankLevel,
    required this.motorStatus,
    required this.ocBreached,
    required this.ucBreached,
    this.createdAt,
    this.createdBy,
  });

  bool get hasBreach => ocBreached || ucBreached;

  factory ModuleActionLogModel.fromJson(Map<String, dynamic> json) =>
      ModuleActionLogModel(
        id: (json['id'] as String?) ?? '',
        serialNumber: (json['serialNumber'] as String?) ?? '',
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
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
        createdBy: json['createdBy'] as String?,
      );

  @override
  List<Object?> get props => [id, serialNumber, motorStatus, createdAt];
}
