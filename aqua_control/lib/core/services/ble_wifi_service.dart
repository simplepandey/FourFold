import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleWifiService {
  static const _serviceUuid    = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const _ssidCharUuid   = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  static const _passCharUuid   = 'beb5483f-36e1-4688-b7f5-ea07361b26a9';
  static const _statusCharUuid = 'beb54840-36e1-4688-b7f5-ea07361b26aa';

  final _devicesCtrl = StreamController<List<BluetoothDevice>>.broadcast();
  final _found = <String, BluetoothDevice>{};

  Stream<List<BluetoothDevice>> get devicesStream => _devicesCtrl.stream;

  StreamSubscription? _scanSub;
  BluetoothDevice? _device;

  Future<void> startScan() async {
    _found.clear();
    await FlutterBluePlus.stopScan();

    _scanSub = FlutterBluePlus.onScanResults.listen((results) {
      bool changed = false;
      for (final r in results) {
        final id = r.device.remoteId.str;
        if (!_found.containsKey(id)) {
          _found[id] = r.device;
          changed = true;
        }
      }
      if (changed && !_devicesCtrl.isClosed) {
        _devicesCtrl.add(List<BluetoothDevice>.unmodifiable(_found.values));
      }
    });

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 20),
      androidUsesFineLocation: false,
    );
  }

  Future<void> stopScan() async {
    await _scanSub?.cancel();
    _scanSub = null;
    await FlutterBluePlus.stopScan();
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    await stopScan();
    await device.connect(timeout: const Duration(seconds: 10));
    _device = device;
  }

  /// Writes [ssid] and [password] then streams every raw status string
  /// the firmware notifies on STATUS_CHAR_UUID until 30 s of silence.
  /// The caller displays each update as-is.
  Stream<String> sendWifiCredentialsStreaming(String ssid, String password) async* {
    if (_device == null) throw Exception('Not connected to any device.');

    final services = await _device!.discoverServices();
    final service = services.firstWhere(
      (s) => s.serviceUuid.toString().toLowerCase() == _serviceUuid,
      orElse: () => throw Exception('AquaControl service not found on this device.'),
    );

    final ssidChar   = _findChar(service, _ssidCharUuid,   'SSID');
    final passChar   = _findChar(service, _passCharUuid,   'Password');
    final statusChar = _findChar(service, _statusCharUuid, 'Status');

    await statusChar.setNotifyValue(true);
    await ssidChar.write(utf8.encode(ssid), withoutResponse: false);
    await Future.delayed(const Duration(milliseconds: 200));
    await passChar.write(utf8.encode(password), withoutResponse: false);

    yield* statusChar.onValueReceived
        .where((v) => v.isNotEmpty)
        .map((v) => utf8.decode(v))
        .timeout(
          const Duration(seconds: 30),
          onTimeout: (sink) => sink.close(),
        );
  }

  Future<void> disconnect() async {
    try { await _device?.disconnect(); } catch (_) {}
    _device = null;
  }

  BluetoothCharacteristic _findChar(BluetoothService service, String uuid, String label) {
    return service.characteristics.firstWhere(
      (c) => c.characteristicUuid.toString().toLowerCase() == uuid,
      orElse: () => throw Exception('$label characteristic not found.'),
    );
  }

  void dispose() {
    stopScan();
    disconnect();
    _devicesCtrl.close();
  }
}
