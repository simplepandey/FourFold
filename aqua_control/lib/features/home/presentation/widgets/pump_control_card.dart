import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/water_level_indicator.dart';
import '../../data/models/pump_status_model.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import 'threshold_settings_sheet.dart';

class PumpControlCard extends StatelessWidget {
  final PumpStatusModel status;
  final bool commandPending;
  const PumpControlCard(
      {super.key, required this.status, this.commandPending = false});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isOn = status.motorStatus == MotorStatus.on;
    final isOff = status.motorStatus == MotorStatus.off;

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
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: isOn ? c.green : c.textMuted,
                    shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(status.pumpName,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary)),
              const Spacer(),
              _ModeChip(mode: status.mode),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              WaterLevelIndicator(
                  percent: status.overheadPercent, label: 'OVERHEAD'),
              Expanded(
                child: Column(children: [
                  _GearButton(
                    color: c.primary,
                    onTap: () => ThresholdSettingsSheet.show(
                      context,
                      overcurrent: status.overcurrent,
                      undercurrent: status.undercurrent,
                      onSave: (oc, uc) => context.read<HomeBloc>().add(
                          SetThresholds(overcurrent: oc, undercurrent: uc)),
                    ),
                  ),
                ]),
              ),
              WaterLevelIndicator(
                  percent: status.undergroundPercent, label: 'UNDERGROUND'),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
                color: c.surfaceElevated,
                borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: MotorMode.values.map((m) {
                final selected = status.mode == m;
                return Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        context.read<HomeBloc>().add(ChangeMotorMode(m)),
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
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected ? c.primary : c.textMuted),
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
              Expanded(
                  child: _ControlButton(
                label: commandPending ? '…' : '✅  Motor ON',
                active: isOn,
                activeColor: c.greenDark,
                disabled: commandPending,
                onTap: () =>
                    context.read<HomeBloc>().add(const ToggleMotor(true)),
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: _ControlButton(
                label: commandPending ? '…' : '⬛  Turn OFF',
                active: isOff,
                activeColor: c.redDark,
                disabled: commandPending,
                onTap: () =>
                    context.read<HomeBloc>().add(const ToggleMotor(false)),
              )),
            ],
          ),
        ],
      ),
    );
  }

  String _modeLabel(MotorMode m) => switch (m) {
        MotorMode.manual => 'Manual',
        MotorMode.auto => 'Auto\nMode',
        MotorMode.schedule => 'Schedule',
      };
}

/// Gear icon that visibly reads as tappable: a soft circular badge with
/// ripple feedback, a slow idle "breathing" pulse to draw the eye, and a
/// bouncy spin on tap so pressing it feels like it actually did something.
class _GearButton extends StatefulWidget {
  final Color color;
  final VoidCallback onTap;
  const _GearButton({required this.color, required this.onTap});

  @override
  State<_GearButton> createState() => _GearButtonState();
}

class _GearButtonState extends State<_GearButton>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;
  late final AnimationController _spinCtrl;
  late final Animation<double> _spin;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _spin = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _spinCtrl, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _spinCtrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    _spinCtrl.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseCtrl, _spinCtrl]),
      builder: (context, child) => Transform.scale(
        scale: _pulse.value,
        child: Transform.rotate(
          angle: _spin.value * 6.28319,
          child: child,
        ),
      ),
      child: Material(
        color: widget.color.withValues(alpha: 0.14),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _handleTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(Icons.settings, color: widget.color, size: 26),
          ),
        ),
      ),
    );
  }
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
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: c.green,
              letterSpacing: 0.8)),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final String label;
  final bool active;
  final bool disabled;
  final Color activeColor;
  final VoidCallback onTap;

  const _ControlButton({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: disabled
              ? c.surfaceElevated.withValues(alpha: 0.5)
              : active
                  ? activeColor.withValues(alpha: 0.25)
                  : c.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: disabled
                ? c.cardBorder
                : active
                    ? activeColor
                    : c.cardBorder,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: disabled
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: c.textMuted),
              )
            : Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: active ? activeColor : c.textMuted)),
      ),
    );
  }
}
