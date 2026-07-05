import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class WaterLevelIndicator extends StatelessWidget {
  final double percent;
  final String label;
  final double width;
  final double height;

  const WaterLevelIndicator({
    super.key,
    required this.percent,
    required this.label,
    this.width = 80,
    this.height = 110,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final clampedPercent = percent.clamp(0.0, 1.0);
    final fillColor = _waterColor(clampedPercent);

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: c.textLabel,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: c.tankBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.cardBorder, width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10.5),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                  height: height * clampedPercent,
                  width: width,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        fillColor.withValues(alpha: 0.7),
                        fillColor,
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    '${(clampedPercent * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _waterColor(double p) {
    if (p < 0.2) return AppColors.red;
    if (p < 0.4) return AppColors.orange;
    return AppColors.waterBlue;
  }
}
