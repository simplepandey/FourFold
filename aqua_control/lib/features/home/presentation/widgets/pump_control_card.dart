import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/water_level_indicator.dart';
import '../../data/models/pump_status_model.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';

class PumpControlCard extends StatelessWidget {
  final PumpStatusModel status;
  const PumpControlCard({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isOn = status.motorStatus == MotorStatus.on;

    return Container(
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
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: isOn ? c.green : c.textMuted, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(status.pumpName, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.textPrimary)),
              const Spacer(),
              _ModeChip(mode: status.mode),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              WaterLevelIndicator(percent: status.overheadPercent, label: 'OVERHEAD'),
              Expanded(
                child: Column(children: [Icon(Icons.settings, color: c.primary, size: 36)]),
              ),
              WaterLevelIndicator(percent: status.undergroundPercent, label: 'UNDERGROUND'),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(color: c.surfaceElevated, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: MotorMode.values.map((m) {
                final selected = status.mode == m;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => context.read<HomeBloc>().add(ChangeMotorMode(m)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? c.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: selected ? Border.all(color: c.primary) : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _modeLabel(m),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? c.primary : c.textMuted),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _ControlButton(label: '✅  Motor ON',  active: isOn,  activeColor: c.greenDark, onTap: () => context.read<HomeBloc>().add(const ToggleMotor(true)))),
              const SizedBox(width: 12),
              Expanded(child: _ControlButton(label: '⬛  Turn OFF', active: !isOn, activeColor: c.redDark,   onTap: () => context.read<HomeBloc>().add(const ToggleMotor(false)))),
            ],
          ),
        ],
      ),
    );
  }

  String _modeLabel(MotorMode m) => switch (m) {
        MotorMode.manual   => 'Manual',
        MotorMode.auto     => 'Auto\nMode',
        MotorMode.schedule => 'Schedule',
      };
}

class _ModeChip extends StatelessWidget {
  final MotorMode mode;
  const _ModeChip({required this.mode});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.green.withValues(alpha: 0.4)),
      ),
      child: Text(mode.name.toUpperCase(),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.green, letterSpacing: 0.8)),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _ControlButton({required this.label, required this.active, required this.activeColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: active ? activeColor.withValues(alpha: 0.25) : c.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? activeColor : c.cardBorder, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: active ? activeColor : c.textMuted)),
      ),
    );
  }
}
