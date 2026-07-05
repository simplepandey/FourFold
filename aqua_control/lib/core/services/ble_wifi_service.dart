import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Status messages pushed through [statusStream] during setup.
enum BleStatus { scanning, found, connecting, connected, sending, success, error }

class BleStatusUpdate {
  final BleStatus status;
  final String message;
  const BleStatusUpdate(this.status, this.message);
}

class BleWifiService {
  // UUIDs must match the firmware defines
  static const _serviceUuid   = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const _ssidCharUuid  = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  static const _passCharUuid  = 'beb5483f-36e1-4688-b7f5-ea07361b26a9';
  static const _statusCharUuid = 'beb54840-36e1-4688-b7f5-ea07361b26aa';
  static const _deviceName    = 'AquaControl-Setup';

  final _statusCtrl = StreamController<BleStatusUpdate>.broadcast();
  Stream<BleStatusUpdate> get statusStream => _statusCtrl.stream;

  BluetoothDevice? _device;
  StreamSubscription<List<ScanResult>>? _scanSub;

  /// Scans for [_deviceName], connects, writes [ssid] and [password], then
  /// subscribes to the status characteristic for firmware confirmation.
  Future<void> configure(String ssid, String password) async {
    try {
      _push(BleStatus.scanning, 'Scanning for $_deviceName…');

      // Stop any prior scan
      await FlutterBluePlus.stopScan();

      final completer = Completer<BluetoothDevice>();

      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          if (r.device.platformName == _deviceName && !completer.isCompleted) {
            completer.complete(r.device);
          }
        }
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: false,
      );

      // Wait for device or timeout
      _device = await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Device not found. Make sure AquaControl-Setup is powered on and nearby.'),
      );

      await FlutterBluePlus.stopScan();
      await _scanSub?.cancel();

      _push(BleStatus.found, 'Device found — connecting…');

      await _device!.connect(timeout: const Duration(seconds: 10));
      _push(BleStatus.connected, 'Connected — discovering services…');

      final services = await _device!.discoverServices();

      final service = services.firstWhere(
        (s) => s.serviceUuid.toString().toLowerCase() == _serviceUuid,
        orElse: () => throw Exception('AquaControl service not found on this device.'),
      );

      final ssidChar = _findChar(service, _ssidCharUuid, 'SSID');
      final passChar = _findChar(service, _passCharUuid, 'Password');
      final statusChar = _findChar(service, _statusCharUuid, 'Status');

      _push(BleStatus.sending, 'Sending Wi-Fi credentials…');

      await ssidChar.write(utf8.encode(ssid), withoutResponse: false);
      await Future.delayed(const Duration(milliseconds: 200));
      await passChar.write(utf8.encode(password), withoutResponse: false);

      // Subscribe to status notifications from the firmware
      await statusChar.setNotifyValue(true);
      final statusValue = await statusChar.lastValueStream
          .where((v) => v.isNotEmpty)
          .first
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw Exception('Timed out waiting for device status.'),
          );

      final statusMsg = utf8.decode(statusValue);
      if (statusMsg.toLowerCase().contains('connected') || statusMsg.toLowerCase().contains('ok')) {
        _push(BleStatus.success, 'Wi-Fi configured! Device is now online.');
      } else {
        _push(BleStatus.error, 'Device reported: $statusMsg');
      }
    } catch (e) {
      _push(BleStatus.error, e.toString().replaceAll('Exception: ', ''));
    } finally {
      await _cleanup();
    }
  }

  BluetoothCharacteristic _findChar(BluetoothService service, String uuid, String label) {
    return service.characteristics.firstWhere(
      (c) => c.characteristicUuid.toString().toLowerCase() == uuid,
      orElse: () => throw Exception('$label characteristic not found.'),
    );
  }

  void _push(BleStatus status, String message) {
    if (!_statusCtrl.isClosed) _statusCtrl.add(BleStatusUpdate(status, message));
  }

  Future<void> _cleanup() async {
    await _scanSub?.cancel();
    _scanSub = null;
    try {
      await _device?.disconnect();
    } catch (_) {}
    _device = null;
  }

  void dispose() {
    _cleanup();
    _statusCtrl.close();
  }
}