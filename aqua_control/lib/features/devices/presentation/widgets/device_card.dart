import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/device_model.dart';

class DeviceCard extends StatelessWidget {
  final DeviceModel device;
  final VoidCallback? onTap;

  const DeviceCard({super.key, required this.device, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final (statusColor, statusLabel) = switch (device.status) {
      DeviceStatus.online  => (c.green,  'Online'),
      DeviceStatus.offline => (c.red,    'Offline'),
      DeviceStatus.fault   => (c.orange, 'Fault'),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: device.status == DeviceStatus.online ? c.green.withValues(alpha: 0.3) : c.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: c.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.water_drop_outlined, color: c.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(device.name,         style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
                  const SizedBox(height: 3),
                  Text(device.serialNumber, style: TextStyle(fontSize: 12, color: c.textMuted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(device.firmwareVersion, style: TextStyle(fontSize: 11, color: c.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
