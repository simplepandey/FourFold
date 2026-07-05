import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/activity_model.dart';

class HistoryEventCard extends StatelessWidget {
  final ActivityModel activity;
  const HistoryEventCard({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isAlert = activity.type == ActivityType.alert;
    final (icon, iconBg, titleColor) = _style(activity.type, c);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isAlert ? c.orange.withValues(alpha: 0.06) : c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isAlert ? c.orange.withValues(alpha: 0.4) : c.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: icon,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity.title,       style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: titleColor)),
                const SizedBox(height: 3),
                Text(activity.description, style: TextStyle(fontSize: 12, color: c.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_formatTime(activity.timestamp), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.textSecondary)),
              if (activity.duration != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: c.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                  child: Text(_formatDuration(activity.duration!), style: TextStyle(fontSize: 11, color: c.primary, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  (Widget, Color, Color) _style(ActivityType type, AppColorScheme c) {
    return switch (type) {
      ActivityType.autoOn    => (const Icon(Icons.check, color: Colors.white, size: 18), c.greenDark,       c.textPrimary),
      ActivityType.autoOff   => (const Text('🤖', style: TextStyle(fontSize: 18)),       c.surfaceElevated, c.textPrimary),
      ActivityType.manualOn  => (const Icon(Icons.check, color: Colors.white, size: 18), c.greenDark,       c.textPrimary),
      ActivityType.manualOff => (const Icon(Icons.stop,  color: Colors.white, size: 18), c.surfaceElevated, c.textPrimary),
      ActivityType.scheduleOn => (const Text('⏰', style: TextStyle(fontSize: 18)),      c.surfaceElevated, c.textPrimary),
      ActivityType.alert     => (const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18), c.orangeDark, c.orange),
    };
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      final m = d.inMinutes.remainder(60);
      return m > 0 ? '${d.inHours}h ${m}m' : '${d.inHours}h';
    }
    return '${d.inMinutes}m';
  }
}
