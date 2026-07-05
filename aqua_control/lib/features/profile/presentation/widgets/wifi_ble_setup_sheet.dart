import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/ble_wifi_service.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';

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
  final _ssidCtrl   = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _formKey    = GlobalKey<FormState>();
  final _ble        = BleWifiService();

  StreamSubscription<BleStatusUpdate>? _sub;
  BleStatusUpdate? _latest;
  bool _busy = false;

  @override
  void dispose() {
    _sub?.cancel();
    _ble.dispose();
    _ssidCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!_formKey.currentState!.validate()) return;

    // Request BLE permissions
    final bluetoothScan    = await Permission.bluetoothScan.request();
    final bluetoothConnect = await Permission.bluetoothConnect.request();
    final location         = await Permission.locationWhenInUse.request();

    if (!bluetoothScan.isGranted || !bluetoothConnect.isGranted || !location.isGranted) {
      if (mounted) _showPermissionDenied();
      return;
    }

    // Check adapter state
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      if (mounted) {
        setState(() => _latest = const BleStatusUpdate(BleStatus.error, 'Please enable Bluetooth and try again.'));
      }
      return;
    }

    setState(() { _busy = true; _latest = null; });

    _sub = _ble.statusStream.listen((update) {
      if (!mounted) return;
      setState(() {
        _latest = update;
        if (update.status == BleStatus.success || update.status == BleStatus.error) {
          _busy = false;
        }
      });
    });

    await _ble.configure(_ssidCtrl.text.trim(), _passCtrl.text);
  }

  void _showPermissionDenied() {
    setState(() => _latest = const BleStatusUpdate(
      BleStatus.error,
      'Bluetooth and location permissions are required. Please grant them in Settings.',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: c.cardBorder),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.divider, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),

            // Title
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
                    Text('Wi-Fi Setup via Bluetooth', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.textPrimary)),
                    Text('Connect to AquaControl-Setup device', style: TextStyle(fontSize: 12, color: c.textMuted)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Form fields (hidden while busy)
            if (!_busy && _latest?.status != BleStatus.success) ...[
              CustomTextField(
                label: 'WI-FI NETWORK NAME (SSID)',
                hint: 'e.g. MyHomeNetwork',
                controller: _ssidCtrl,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'SSID is required' : null,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'WI-FI PASSWORD',
                hint: '••••••••',
                controller: _passCtrl,
                obscureText: true,
                validator: (v) => (v == null || v.length < 8) ? 'Password must be at least 8 characters' : null,
              ),
              const SizedBox(height: 24),
              CustomButton(label: 'Connect & Configure', onTap: _start),
            ],

            // Progress / result
            if (_latest != null) ...[
              const SizedBox(height: 16),
              _StatusCard(update: _latest!),
            ],

            // Busy animation
            if (_busy && _latest == null) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],

            // Retry / close after result
            if (!_busy && _latest != null) ...[
              const SizedBox(height: 20),
              if (_latest!.status == BleStatus.error)
                CustomButton(
                  label: 'Try Again',
                  variant: ButtonVariant.secondary,
                  onTap: () => setState(() { _latest = null; }),
                ),
              if (_latest!.status == BleStatus.success)
                CustomButton(label: 'Done', onTap: () => Navigator.pop(context)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final BleStatusUpdate update;
  const _StatusCard({required this.update});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isError   = update.status == BleStatus.error;
    final isSuccess = update.status == BleStatus.success;

    final color  = isError ? c.red : isSuccess ? c.green : const Color(0xFF0A84FF);
    final icon   = isError ? Icons.error_outline : isSuccess ? Icons.check_circle_outline : Icons.bluetooth_searching_rounded;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          isSuccess || isError
              ? Icon(icon, color: color, size: 22)
              : SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
                ),
          const SizedBox(width: 12),
          Expanded(child: Text(update.message, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
