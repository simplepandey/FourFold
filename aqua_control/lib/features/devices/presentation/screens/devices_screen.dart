import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/device_model.dart';
import '../widgets/device_card.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final devices = DeviceModel.mockList;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('My Devices', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: c.textPrimary)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {},
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(color: c.surfaceElevated, borderRadius: BorderRadius.circular(12)),
                            child: Icon(Icons.refresh, color: c.textSecondary, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // WiFi status
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: c.green, shape: BoxShape.circle)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('GreenValley_WiFi_2.4G', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
                                const SizedBox(height: 2),
                                Text('Society network • Strong signal', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                              ],
                            ),
                          ),
                          Icon(Icons.signal_wifi_4_bar, color: c.green, size: 22),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Text('Registered Devices', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => context.push('/devices/add'),
                          child: Text('+ Add New', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...devices.map((d) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: DeviceCard(device: d),
                        )),
                    const SizedBox(height: 24),
                    Text('QUICK ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textLabel, letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    _QuickActionTile(icon: Icons.satellite_alt_outlined, title: 'Re-provision Device',  subtitle: 'Change WiFi credentials', onTap: () {}),
                    Divider(color: c.divider, height: 1),
                    _QuickActionTile(
                      icon: Icons.system_update_outlined,
                      title: 'Check for Updates',
                      subtitle: 'OTA firmware update',
                      onTap: () {},
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: c.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: c.green.withValues(alpha: 0.3)),
                        ),
                        child: Text('v2.4.0 ready', style: TextStyle(fontSize: 11, color: c.green, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _QuickActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: c.surface,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: c.surfaceElevated, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: c.textSecondary, size: 18),
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
            trailing ?? Icon(Icons.arrow_forward_ios, size: 14, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}
