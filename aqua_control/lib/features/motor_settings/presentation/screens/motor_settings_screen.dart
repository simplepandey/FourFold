import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../data/models/motor_settings_model.dart';
import '../widgets/current_gauge_widget.dart';
import '../widgets/protection_toggle_tile.dart';

class MotorSettingsScreen extends StatefulWidget {
  const MotorSettingsScreen({super.key});

  @override
  State<MotorSettingsScreen> createState() => _MotorSettingsScreenState();
}

class _MotorSettingsScreenState extends State<MotorSettingsScreen> {
  MotorSettingsModel _settings = MotorSettingsModel.mock;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: c.surfaceElevated, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.arrow_back_ios_new, size: 16, color: c.textPrimary),
          ),
        ),
        title: Text('Motor Settings', style: TextStyle(color: c.textPrimary)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Live current monitor card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: c.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('⚡ Live Current Monitor',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: c.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: c.green.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Container(width: 6, height: 6, decoration: BoxDecoration(color: c.green, shape: BoxShape.circle)),
                              const SizedBox(width: 5),
                              Text('LIVE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.green, letterSpacing: 0.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        CurrentGaugeWidget(current: _settings.liveCurrent),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            children: [
                              _ThresholdField(label: '⬆ OVER\nCURRENT',  value: _settings.overCurrentThreshold,  color: c.red),
                              const SizedBox(height: 12),
                              _ThresholdField(label: '⬇ UNDER\nCURRENT', value: _settings.underCurrentThreshold, color: c.orange),
                              const SizedBox(height: 12),
                              CustomButton(label: '⚡ Auto-Detect Thresholds', height: 40, onTap: () {}),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Voltage card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: c.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.bolt, color: c.orange, size: 22),
                    ),
                    const SizedBox(width: 16),
                    _VoltageItem(label: 'LIVE',    value: '${_settings.liveVoltage.round()}V',   color: c.green),
                    const SizedBox(width: 20),
                    _VoltageItem(label: 'OV TRIP', value: '${_settings.ovTripVoltage.round()}V', color: c.red),
                    const SizedBox(width: 20),
                    _VoltageItem(label: 'UV TRIP', value: '${_settings.uvTripVoltage.round()}V', color: c.orange),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('PROTECTION SETTINGS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textLabel, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.cardBorder),
                ),
                child: Column(
                  children: [
                    ProtectionToggleTile(
                      icon: const Text('🛡️', style: TextStyle(fontSize: 18)),
                      title: 'Dry Run Protection',
                      subtitle: 'Stop motor if current < threshold',
                      value: _settings.dryRunProtection,
                      onChanged: (v) => setState(() => _settings = _settings.copyWith(dryRunProtection: v)),
                    ),
                    Divider(color: c.divider, height: 1, indent: 16),
                    ProtectionToggleTile(
                      icon: Icon(Icons.water_drop, color: c.primary, size: 20),
                      title: 'Overflow Protection',
                      subtitle: 'Auto-off when tank full',
                      value: _settings.overflowProtection,
                      onChanged: (v) => setState(() => _settings = _settings.copyWith(overflowProtection: v)),
                    ),
                    Divider(color: c.divider, height: 1, indent: 16),
                    ListTile(
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: c.surfaceElevated, borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.timer_outlined, color: c.textSecondary, size: 18),
                      ),
                      title: Text('Max Run Time',   style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
                      subtitle: Text('Auto-off after limit', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                      trailing: Text('${_settings.maxRunTimeHours} hrs →', style: TextStyle(fontSize: 13, color: c.textSecondary)),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThresholdField extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _ThresholdField({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Row(
      children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color, height: 1.3)),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: c.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            alignment: Alignment.center,
            child: Text(value.toStringAsFixed(1), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
          ),
        ),
      ],
    );
  }
}

class _VoltageItem extends StatelessWidget {
  final String label, value;
  final Color color;
  const _VoltageItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: c.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      ],
    );
  }
}
