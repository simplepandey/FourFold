import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class ThresholdSettingsSheet extends StatefulWidget {
  final double overcurrent;
  final double undercurrent;
  final void Function(double overcurrent, double undercurrent) onSave;

  const ThresholdSettingsSheet({
    super.key,
    required this.overcurrent,
    required this.undercurrent,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required double overcurrent,
    required double undercurrent,
    required void Function(double overcurrent, double undercurrent) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ThresholdSettingsSheet(
        overcurrent: overcurrent,
        undercurrent: undercurrent,
        onSave: onSave,
      ),
    );
  }

  @override
  State<ThresholdSettingsSheet> createState() => _ThresholdSettingsSheetState();
}

class _ThresholdSettingsSheetState extends State<ThresholdSettingsSheet> {
  late final TextEditingController _ocCtrl;
  late final TextEditingController _ucCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ocCtrl =
        TextEditingController(text: widget.overcurrent.toStringAsFixed(1));
    _ucCtrl =
        TextEditingController(text: widget.undercurrent.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _ocCtrl.dispose();
    _ucCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final oc = double.tryParse(_ocCtrl.text.trim());
    final uc = double.tryParse(_ucCtrl.text.trim());
    if (oc == null || uc == null) {
      setState(() => _error = 'Enter valid numbers for both thresholds');
      return;
    }
    if (oc < 0 || uc < 0) {
      setState(() => _error = 'Thresholds cannot be negative');
      return;
    }
    Navigator.pop(context);
    widget.onSave(oc, uc);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.cardBorder),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: c.divider, borderRadius: BorderRadius.circular(3)),
            ),
          ),
          const SizedBox(height: 18),
          Text('Current Thresholds',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary)),
          const SizedBox(height: 4),
          Text(
            'Set the overcurrent and undercurrent trip points for this pump.',
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          ),
          const SizedBox(height: 20),
          _ThresholdField(
              label: 'Overcurrent (A)', controller: _ocCtrl, colors: c),
          const SizedBox(height: 14),
          _ThresholdField(
              label: 'Undercurrent (A)', controller: _ucCtrl, colors: c),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.error_outline, size: 14, color: c.red),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(_error!,
                        style: TextStyle(fontSize: 12, color: c.red))),
              ],
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _save,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                    color: c.primary, borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: const Text('Save',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThresholdField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final AppColorScheme colors;
  const _ThresholdField({
    required this.label,
    required this.controller,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: c.textMuted)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: c.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.cardBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(fontSize: 14, color: c.textPrimary),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
