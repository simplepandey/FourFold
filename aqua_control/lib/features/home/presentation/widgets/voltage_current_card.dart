import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class VoltageCurrentCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final String subtitle;
  final String emoji;
  final Color valueColor;

  const VoltageCurrentCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.subtitle,
    required this.emoji,
    this.valueColor = AppColors.green,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textLabel, letterSpacing: 1.0)),
                Text(emoji, style: const TextStyle(fontSize: 18)),
              ],
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(text: value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: valueColor)),
                  TextSpan(text: unit,  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 12, color: c.textSecondary)),
          ],
        ),
      ),
    );
  }
}
