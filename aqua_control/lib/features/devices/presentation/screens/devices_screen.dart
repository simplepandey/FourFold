import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../data/models/device_model.dart';
import '../../data/repositories/device_repository.dart';
import '../widgets/device_card.dart';
import '../../../home/presentation/screens/home_screen.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  List<DeviceModel> _devices = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() { _loading = true; _error = null; });
    try {
      final authState = context.read<AuthBloc>().state;
      final userId = authState is AuthAuthenticated ? authState.user.id : '';
      final devices = await context.read<DeviceRepository>().fetchDevices(userId);
      if (mounted) setState(() { _devices = devices; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error   = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

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
                          onTap: _loading ? null : _loadDevices,
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(color: c.surfaceElevated, borderRadius: BorderRadius.circular(12)),
                            child: _loading
                                ? Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
                                  )
                                : Icon(Icons.refresh, color: c.textSecondary, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Text('Registered Devices', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () async {
                            await context.push('/devices/add');
                            _loadDevices();
                            HomeScreen.reload();
                          },
                          child: Text('+ Add New', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_loading)
                      Center(child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: CircularProgressIndicator(color: c.primary),
                      ))
                    else if (_error != null)
                      _ErrorBanner(message: _error!, onRetry: _loadDevices)
                    else if (_devices.isEmpty)
                      _EmptyState(onAdd: () async {
                        await context.push('/devices/add');
                        _loadDevices();
                        HomeScreen.reload();
                      })
                    else
                      ..._devices.map((d) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: DeviceCard(device: d),
                          )),

                    const SizedBox(height: 24),
                    Text('QUICK ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textLabel, letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    _QuickActionTile(icon: Icons.satellite_alt_outlined, title: 'Re-provision Device',  subtitle: 'Change WiFi credentials', onTap: () {}),
                    Divider(color: c.divider, height: 1),
                    _QuickActionTile(icon: Icons.system_update_outlined, title: 'Check for Updates', subtitle: 'OTA firmware update', onTap: () {}),
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

// ─── Empty state ──────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: c.surfaceElevated, shape: BoxShape.circle),
            child: Icon(Icons.devices_other_outlined, color: c.textMuted, size: 30),
          ),
          const SizedBox(height: 16),
          Text('No devices registered', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
          const SizedBox(height: 6),
          Text('Add your first AquaControl module', style: TextStyle(fontSize: 13, color: c.textSecondary)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.primary.withValues(alpha: 0.3)),
              ),
              child: Text('+ Add Device', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.primary)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Error banner ─────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: c.red, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(fontSize: 13, color: c.red))),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRetry,
            child: Text('Retry', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.primary)),
          ),
        ],
      ),
    );
  }
}

// ─── Quick action tile ────────────────────────────────────────

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;

  const _QuickActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

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
            Icon(Icons.arrow_forward_ios, size: 14, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}
