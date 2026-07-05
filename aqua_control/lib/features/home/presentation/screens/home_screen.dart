import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import '../widgets/voltage_current_card.dart';
import '../widgets/pump_control_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeBloc()..add(const LoadHomeData()),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: BlocBuilder<HomeBloc, HomeState>(
          builder: (context, state) {
            if (state is HomeLoading) {
              return Center(child: CircularProgressIndicator(color: c.primary));
            }
            if (state is HomeError) {
              return Center(child: Text(state.message, style: TextStyle(color: c.red)));
            }
            if (state is! HomeLoaded) return const SizedBox();
            final s = state;

            return RefreshIndicator(
              color: c.primary,
              backgroundColor: c.surface,
              onRefresh: () async => context.read<HomeBloc>().add(const RefreshStatus()),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: c.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.water_drop, color: c.primary, size: 18),
                              ),
                              const SizedBox(width: 10),
                              RichText(
                                text: TextSpan(
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                  children: [
                                    TextSpan(text: 'Aqua',    style: TextStyle(color: c.textPrimary)),
                                    TextSpan(text: 'Control', style: TextStyle(color: c.primary)),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Stack(
                                children: [
                                  _AppBarButton(icon: Icons.notifications_outlined, onTap: () {}),
                                  Positioned(
                                    right: 8, top: 8,
                                    child: Container(
                                      width: 8, height: 8,
                                      decoration: BoxDecoration(color: c.red, shape: BoxShape.circle),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              _AppBarButton(icon: Icons.settings_outlined, onTap: () => context.push('/home/motor-settings')),
                            ],
                          ),
                          const SizedBox(height: 24),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                              children: [
                                TextSpan(text: '${_greeting()}, ', style: TextStyle(color: c.textPrimary)),
                                TextSpan(text: s.userName,          style: TextStyle(color: c.primary)),
                                const TextSpan(text: ' 👋'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('${s.societyInfo} • ${s.motorsOnline} motors online',
                              style: TextStyle(fontSize: 13, color: c.textSecondary)),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              VoltageCurrentCard(
                                label: 'VOLTAGE',
                                value: s.status.voltage.round().toString(),
                                unit: 'v',
                                subtitle: 'Normal range',
                                emoji: '⚡',
                                valueColor: c.green,
                              ),
                              const SizedBox(width: 12),
                              VoltageCurrentCard(
                                label: 'CURRENT',
                                value: s.status.current.toStringAsFixed(1),
                                unit: 'A',
                                subtitle: s.status.motorStatus.name == 'on' ? 'Motor running' : 'Motor idle',
                                emoji: '🌊',
                                valueColor: c.primary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          PumpControlCard(status: s.status),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AppBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AppBarButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: c.surfaceElevated, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: c.textSecondary, size: 20),
      ),
    );
  }
}
