import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../../core/constants/app_colors.dart';

class CurrentGaugeWidget extends StatelessWidget {
  final double current;
  final double maxCurrent;

  const CurrentGaugeWidget({super.key, required this.current, this.maxCurrent = 10.0});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final fraction = (current / maxCurrent).clamp(0.0, 1.0);

    return SizedBox(
      width: 110,
      height: 90,
      child: CustomPaint(
        painter: _GaugePainter(fraction: fraction, trackColor: c.gaugeTrack),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(current.toStringAsFixed(1),
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: c.primary)),
            Text('AMPS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textLabel, letterSpacing: 1.0)),
          ],
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double fraction;
  final Color trackColor;

  _GaugePainter({required this.fraction, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height - 10;
    final radius = size.width / 2 - 8;
    const startAngle = math.pi;
    const sweepAngle = math.pi;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      startAngle, sweepAngle, false,
      Paint()..color = trackColor..strokeWidth = 10..style = PaintingStyle.stroke..strokeCap = StrokeCap.round,
    );

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      startAngle, sweepAngle * fraction, false,
      Paint()
        ..shader = const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight])
            .createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..strokeWidth = 10
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.fraction != fraction || old.trackColor != trackColor;
}
