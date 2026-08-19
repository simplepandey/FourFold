import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/ble_wifi_service.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';

enum _Phase { init, noPermission, btOff, scanning, connecting, wifiForm, sending, success, error }

class WifiBleSetupSheet extends StatefulWidget {
  const WifiBleSetupSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const WifiBleSetupSheet(),
    );
  }

  @override
  State<WifiBleSetupSheet> createState() => _WifiBleSetupSheetState();
}

class _WifiBleSetupSheetState extends State<WifiBleSetupSheet> {
  final _ssidCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey  = GlobalKey<FormState>();
  final _ble      = BleWifiService();

  _Phase _phase    = _Phase.init;
  String _errorMsg = '';
  String _statusMsg = '';
  bool   _scanning = false;

  List<BluetoothDevice> _devices = [];
  StreamSubscription<List<BluetoothDevice>>? _devicesSub;
  StreamSubscription<bool>?   _isScanSub;
  StreamSubscription<String>? _statusSub;

  BluetoothDevice? _connectedDevice;

  @override
  void initState() {
    super.initState();
    _isScanSub = FlutterBluePlus.isScanning.listen((scanning) {
      if (mounted && _phase == _Phase.scanning) {
        setState(() => _scanning = scanning);
      }
    });
    _init();
  }

  @override
  void dispose() {
    _devicesSub?.cancel();
    _isScanSub?.cancel();
    _statusSub?.cancel();
    _ble.dispose();
    _ssidCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (!mounted) return;
    setState(() => _phase = _Phase.init);

    // Android needs explicit runtime permission requests before BLE APIs work.
    // iOS does NOT — permission is triggered by CBCentralManager initialisation
    // (which happens when we first listen to adapterState below).
    if (defaultTargetPlatform == TargetPlatform.android) {
      final btScan    = await Permission.bluetoothScan.request();
      final btConnect = await Permission.bluetoothConnect.request();
      if (!btScan.isGranted || !btConnect.isGranted) {
        if (!mounted) return;
        setState(() => _phase = _Phase.noPermission);
        return;
      }
    }

    // On iOS this creates CBCentralManager, which triggers the permission dialog.
    // We skip BluetoothAdapterState.unknown (transient init state) so we always
    // get a settled answer: on / off / unauthorized / unavailable.
    final adapterState = await FlutterBluePlus.adapterState
        .where((s) => s != BluetoothAdapterState.unknown)
        .first;

    if (adapterState == BluetoothAdapterState.unauthorized) {
      if (!mounted) return;
      setState(() => _phase = _Phase.noPermission);
      return;
    }

    if (adapterState != BluetoothAdapterState.on) {
      if (mounted) setState(() => _phase = _Phase.btOff);
      FlutterBluePlus.adapterState.firstWhere((s) => s == BluetoothAdapterState.on).then((_) {
        if (mounted) _startScanning();
      });
      return;
    }

    _startScanning();
  }

  Future<void> _startScanning() async {
    if (!mounted) return;
    setState(() {
      _phase    = _Phase.scanning;
      _scanning = true;
      _devices  = [];
    });

    _devicesSub?.cancel();
    _devicesSub = _ble.devicesStream.listen((devices) {
      if (mounted) setState(() => _devices = devices);
    });

    try {
      await _ble.startScan();
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase    = _Phase.error;
          _errorMsg = 'Scan failed: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    }
    // _scanning is driven by FlutterBluePlus.isScanning stream above
  }

  Future<void> _connectTo(BluetoothDevice device) async {
    setState(() => _phase = _Phase.connecting);

    try {
      await _ble.connectToDevice(device);
      _connectedDevice = device;
      if (mounted) setState(() => _phase = _Phase.wifiForm);
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase    = _Phase.error;
          _errorMsg = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _sendCredentials() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _phase = _Phase.sending; _statusMsg = ''; });

    await _statusSub?.cancel();
    _statusSub = _ble.sendWifiCredentialsStreaming(
      _ssidCtrl.text.trim(),
      _passCtrl.text,
    ).listen(
      (status) {
        if (!mounted) return;
        // The firmware's final messages say "successfully" / "failed" —
        // act on those instead of just displaying every message and
        // assuming stream-completion means success (it doesn't: the
        // device can go quiet after a failed attempt just as easily as
        // after a real success).
        final lower = status.toLowerCase();
        if (lower.contains('successfully')) {
          setState(() { _phase = _Phase.success; _statusMsg = status; });
          _statusSub?.cancel();
        } else if (lower.contains('failed')) {
          setState(() { _phase = _Phase.error; _errorMsg = status; });
          _statusSub?.cancel();
        } else {
          setState(() => _statusMsg = status);
        }
      },
      onError: (Object e) {
        if (mounted) {
          setState(() {
            _phase    = _Phase.error;
            _errorMsg = e.toString().replaceAll('Exception: ', '');
          });
        }
      },
      onDone: () {
        // Reached only if the stream ended without ever sending an explicit
        // success/failure message (e.g. the device went silent and the 30s
        // idle timeout in sendWifiCredentialsStreaming fired) — treat that
        // as inconclusive, not success.
        if (mounted && _phase == _Phase.sending) {
          setState(() {
            _phase    = _Phase.error;
            _errorMsg = 'No response from the device — it may still be '
                'trying to connect. Check again shortly, or try again.';
          });
        }
      },
      cancelOnError: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c      = context.appColors;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: c.cardBorder),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: c.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header row
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A84FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bluetooth_rounded, color: Color(0xFF0A84FF), size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _headerTitle,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.textPrimary),
                  ),
                  Text(
                    _headerSubtitle,
                    style: TextStyle(fontSize: 12, color: c.textMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Phase content — Expanded so device list can scroll within the sheet
          Expanded(child: _buildPhaseContent(c)),
        ],
      ),
    );
  }

  String get _headerTitle {
    switch (_phase) {
      case _Phase.init:         return 'Wi-Fi Setup via Bluetooth';
      case _Phase.noPermission: return 'Permission Required';
      case _Phase.btOff:        return 'Bluetooth Required';
      case _Phase.scanning:     return 'Searching for Devices';
      case _Phase.connecting:   return 'Connecting…';
      case _Phase.wifiForm:     return 'Send Wi-Fi Credentials';
      case _Phase.sending:      return 'Configuring Device';
      case _Phase.success:      return 'Setup Complete';
      case _Phase.error:        return 'Something Went Wrong';
    }
  }

  String get _headerSubtitle {
    switch (_phase) {
      case _Phase.wifiForm:
        final name = _connectedDevice?.platformName;
        return name != null && name.isNotEmpty ? 'Connected to $name' : 'Connected';
      case _Phase.success:  return 'Device is online';
      case _Phase.scanning: return _scanning ? 'Looking for nearby devices…' : 'Scan complete';
      default:              return 'AquaControl setup';
    }
  }

  Widget _buildPhaseContent(AppColorScheme c) {
    switch (_phase) {
      case _Phase.init:
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: CircularProgressIndicator(),
          ),
        );

      case _Phase.noPermission:
        return _NoPermissionCard(colors: c, onRetry: _init);

      case _Phase.btOff:
        return _BtOffCard(colors: c, onRetry: _init);

      case _Phase.scanning:
        return _ScanningContent(
          devices: _devices,
          scanning: _scanning,
          colors: c,
          onDeviceTap: _connectTo,
          onRetry: _startScanning,
        );

      case _Phase.connecting:
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFF0A84FF)),
                const SizedBox(height: 16),
                Text(
                  'Connecting to ${_connectedDevice?.platformName.isNotEmpty == true ? _connectedDevice!.platformName : "device"}…',
                  style: TextStyle(color: c.textMuted, fontSize: 14),
                ),
              ],
            ),
          ),
        );

      case _Phase.wifiForm:
        return _WifiFormContent(
          formKey: _formKey,
          ssidCtrl: _ssidCtrl,
          passCtrl: _passCtrl,
          colors: c,
          onSend: _sendCredentials,
        );

      case _Phase.sending:
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_statusMsg.isEmpty)
                  const CircularProgressIndicator(color: Color(0xFF0A84FF))
                else
                  const Icon(Icons.wifi_rounded, color: Color(0xFF0A84FF), size: 44),
                const SizedBox(height: 18),
                Text(
                  _statusMsg.isEmpty ? 'Sending Wi-Fi credentials…' : _statusMsg,
                  style: TextStyle(
                    color: _statusMsg.isEmpty ? c.textMuted : c.textPrimary,
                    fontSize: 15,
                    fontWeight: _statusMsg.isEmpty ? FontWeight.w400 : FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_statusMsg.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Waiting for more updates from device…',
                    style: TextStyle(color: c.textMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        );

      case _Phase.success:
        return _ResultCard(
          success: true,
          message: _statusMsg.isNotEmpty
              ? _statusMsg
              : 'Wi-Fi credentials sent successfully.',
          actionLabel: 'Done',
          colors: c,
          onAction: () => Navigator.pop(context),
        );

      case _Phase.error:
        return _ResultCard(
          success: false,
          message: _errorMsg,
          actionLabel: 'Try Again',
          colors: c,
          // Setting _phase alone previously left the sheet stuck on a
          // spinner forever — nothing was listening for that transition.
          // _init() is what actually restarts permission-check → scan.
          onAction: () {
            setState(() => _errorMsg = '');
            _init();
          },
        );
    }
  }
}

// ─── No Permission ─────────────────────────────────────────────────────────

class _NoPermissionCard extends StatelessWidget {
  final AppColorScheme colors;
  final VoidCallback onRetry;

  const _NoPermissionCard({required this.colors, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.bluetooth_disabled_rounded, color: colors.red, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bluetooth access denied',
                        style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'AquaControl needs Bluetooth permission to scan for your water controller. Please allow it in Settings.',
                        style: TextStyle(color: colors.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          CustomButton(
            label: 'Open Settings',
            onTap: () => openAppSettings(),
          ),
          const SizedBox(height: 12),
          CustomButton(
            label: 'Already Granted — Retry',
            variant: ButtonVariant.secondary,
            onTap: onRetry,
          ),
        ],
      ),
    );
  }
}

// ─── BT Off ────────────────────────────────────────────────────────────────

class _BtOffCard extends StatelessWidget {
  final AppColorScheme colors;
  final VoidCallback onRetry;

  const _BtOffCard({required this.colors, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.bluetooth_disabled_rounded, color: colors.orange, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bluetooth is off', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text('Enable Bluetooth in Settings to scan for your AquaControl device.', style: TextStyle(color: colors.textMuted, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          CustomButton(
            label: 'Open Bluetooth Settings',
            onTap: () => openAppSettings(),
          ),
          const SizedBox(height: 12),
          CustomButton(
            label: 'Already On — Retry',
            variant: ButtonVariant.secondary,
            onTap: onRetry,
          ),
        ],
      ),
    );
  }
}

// ─── Scanning + Device List ────────────────────────────────────────────────

class _ScanningContent extends StatelessWidget {
  final List<BluetoothDevice> devices;
  final bool scanning;
  final AppColorScheme colors;
  final void Function(BluetoothDevice) onDeviceTap;
  final VoidCallback onRetry;

  const _ScanningContent({
    required this.devices,
    required this.scanning,
    required this.colors,
    required this.onDeviceTap,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Scanning indicator (fixed height)
        if (scanning)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0A84FF).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0A84FF).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0A84FF)),
                ),
                const SizedBox(width: 12),
                Text('Scanning for nearby devices…', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
              ],
            ),
          ),

        // Device list — Expanded so it scrolls within the sheet
        if (devices.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '${devices.length} device${devices.length == 1 ? '' : 's'} found',
            style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: devices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _DeviceTile(
                device: devices[i],
                colors: colors,
                onTap: () => onDeviceTap(devices[i]),
              ),
            ),
          ),
        ],

        // Empty state after scan finished
        if (!scanning && devices.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bluetooth_searching_rounded, color: colors.textMuted, size: 48),
                  const SizedBox(height: 12),
                  Text('No devices found', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text('Make sure your AquaControl device is powered on and nearby.', textAlign: TextAlign.center, style: TextStyle(color: colors.textMuted, fontSize: 13)),
                  const SizedBox(height: 24),
                  CustomButton(label: 'Scan Again', onTap: onRetry),
                ],
              ),
            ),
          ),

        // Still scanning, no devices yet — just let the indicator sit at top
        if (scanning && devices.isEmpty) const Spacer(),
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final BluetoothDevice device;
  final AppColorScheme colors;
  final VoidCallback onTap;

  const _DeviceTile({required this.device, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = device.platformName.isNotEmpty ? device.platformName : 'Unknown Device';
    final id   = device.remoteId.str;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A84FF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bluetooth_rounded, color: Color(0xFF0A84FF), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(id, style: TextStyle(color: colors.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Wi-Fi Form ─────────────────────────────────────────────────────────────

class _WifiFormContent extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController ssidCtrl;
  final TextEditingController passCtrl;
  final AppColorScheme colors;
  final VoidCallback onSend;

  const _WifiFormContent({
    required this.formKey,
    required this.ssidCtrl,
    required this.passCtrl,
    required this.colors,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomTextField(
            label: 'WI-FI NETWORK NAME (SSID)',
            hint: 'e.g. MyHomeNetwork',
            controller: ssidCtrl,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'SSID is required' : null,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'WI-FI PASSWORD',
            hint: '••••••••',
            controller: passCtrl,
            obscureText: true,
            validator: (v) => (v == null || v.length < 8) ? 'Password must be at least 8 characters' : null,
          ),
          const SizedBox(height: 24),
          CustomButton(label: 'Send Wi-Fi Credentials', onTap: onSend),
        ],
      ),
    );
  }
}

// ─── Result card ────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final bool success;
  final String message;
  final String actionLabel;
  final AppColorScheme colors;
  final VoidCallback onAction;

  const _ResultCard({
    required this.success,
    required this.message,
    required this.actionLabel,
    required this.colors,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final color = success ? colors.green : colors.red;
    final icon  = success ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(message, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        CustomButton(
          label: actionLabel,
          variant: success ? ButtonVariant.primary : ButtonVariant.secondary,
          onTap: onAction,
        ),
      ],
    );
  }
}
