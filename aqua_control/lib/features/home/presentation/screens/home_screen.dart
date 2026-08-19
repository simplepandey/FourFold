import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../devices/data/models/device_model.dart';
import '../../../devices/data/repositories/device_repository.dart';

class HomeScreen extends StatefulWidget {
  static final _key = GlobalKey<_HomeScreenState>();

  HomeScreen() : super(key: _key);

  static void reload() => _key.currentState?._loadModules();

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<DeviceModel> _modules = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadModules();
  }

  Future<void> _loadModules() async {
    setState(() { _loading = true; _error = null; });
    try {
      final authState = context.read<AuthBloc>().state;
      final userId = authState is AuthAuthenticated ? authState.user.id : '';
      final modules = await context.read<DeviceRepository>().fetchDevices(userId);
      if (mounted) setState(() { _modules = modules; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final authState = context.read<AuthBloc>().state;
    final user     = authState is AuthAuthenticated ? authState.user : null;
    final userName = (user?.name.isNotEmpty ?? false) ? user!.name : 'User';

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: c.primary,
          backgroundColor: c.surface,
          onRefresh: _loadModules,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Greeting ──────────────────────────────────────
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                          children: [
                            TextSpan(text: '${ _greeting()}, ', style: TextStyle(color: c.textPrimary)),
                            TextSpan(text: userName,            style: TextStyle(color: c.primary)),
                            const TextSpan(text: ' 👋'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _loading
                            ? 'Loading modules…'
                            : _error != null
                                ? 'Could not load modules'
                                : '${_modules.length} module${_modules.length == 1 ? '' : 's'} registered · ${_modules.length} online',
                        style: TextStyle(fontSize: 14, color: c.textSecondary),
                      ),
                      const SizedBox(height: 28),

                      // ── Section label ─────────────────────────────────
                      Text(
                        'YOUR MODULES',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: c.textMuted),
                      ),
                      const SizedBox(height: 14),

                      // ── Body ──────────────────────────────────────────
                      if (_loading)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: CircularProgressIndicator(color: c.primary),
                          ),
                        )
                      else if (_error != null)
                        _ErrorState(message: _error!, onRetry: _loadModules, colors: c)
                      else if (_modules.isEmpty)
                        _EmptyState(colors: c)
                      else
                        ..._modules.map((m) => _ModuleCard(
                              device: m,
                              colors: c,
                              onTap:  () => context.push('/home/module-detail', extra: m),
                            )),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Module card ──────────────────────────────────────────────

class _ModuleCard extends StatelessWidget {
  final DeviceModel device;
  final AppColorScheme colors;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.device,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.cardBorder),
        ),
        child: Row(
          children: [
            // ── Icon + admin badge ───────────────────────────
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: c.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: device.isAdmin
                        ? Border.all(color: const Color(0xFFFFB020), width: 1.5)
                        : null,
                  ),
                  child: Icon(Icons.water_drop, color: c.primary, size: 22),
                ),
                if (device.isAdmin)
                  Positioned(
                    bottom: -5, right: -5,
                    child: Container(
                      width: 19, height: 19,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB020),
                        shape: BoxShape.circle,
                        border: Border.all(color: c.surface, width: 2),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 3)],
                      ),
                      alignment: Alignment.center,
                      child: const Text('♛', style: TextStyle(fontSize: 9, color: Color(0xFF1A1200))),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),

            // ── Info ─────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.displayName,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: c.green,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: c.green.withValues(alpha: 0.5), blurRadius: 4)],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        device.displaySubtitle,
                        style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.primary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'AquaControl',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: c.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Icon(Icons.chevron_right, color: c.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final AppColorScheme colors;
  const _EmptyState({required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: c.surfaceElevated, shape: BoxShape.circle),
            child: Icon(Icons.water_drop_outlined, color: c.textMuted, size: 32),
          ),
          const SizedBox(height: 16),
          Text('No modules yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary)),
          const SizedBox(height: 6),
          Text('Register a device from the Devices tab.', style: TextStyle(fontSize: 13, color: c.textSecondary)),
        ],
      ),
    );
  }
}

// ─── Error state ──────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final AppColorScheme colors;
  const _ErrorState({required this.message, required this.onRetry, required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: c.red, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.primary.withValues(alpha: 0.3)),
              ),
              child: Text('Retry', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.primary)),
            ),
          ),
        ],
      ),
    );
  }
}
