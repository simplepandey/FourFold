import 'package:equatable/equatable.dart';

enum DeviceStatus { online, offline, fault }

class DeviceModel extends Equatable {
  final String id;
  final String name;
  final String serialNumber;
  final DeviceStatus status;
  final String firmwareVersion;
  final String? latestFirmwareVersion;

  const DeviceModel({
    required this.id,
    required this.name,
    required this.serialNumber,
    required this.status,
    required this.firmwareVersion,
    this.latestFirmwareVersion,
  });

  bool get hasUpdate =>
      latestFirmwareVersion != null && latestFirmwareVersion != firmwareVersion;

  static List<DeviceModel> get mockList => const [
        DeviceModel(
          id: 'PAD_dc9854f924f0',
          name: 'Main Pump Controller',
          serialNumber: 'PAD_dc9854f924f0',
          status: DeviceStatus.online,
          firmwareVersion: 'v2.3.1',
          latestFirmwareVersion: 'v2.4.0',
        ),
        DeviceModel(
          id: 'PAD_a1b2c3d4e5f6',
          name: 'Backup Pump',
          serialNumber: 'PAD_a1b2c3d4e5f6',
          status: DeviceStatus.offline,
          firmwareVersion: 'v2.1.0',
        ),
      ];

  @override
  List<Object?> get props => [id, status];
}
