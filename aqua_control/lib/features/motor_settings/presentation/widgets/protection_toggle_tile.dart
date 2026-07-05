import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class ProtectionToggleTile extends StatelessWidget {
  final Widget icon;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const ProtectionToggleTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: c.surfaceElevated, borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: icon,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: c.textSecondary)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
