import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../widgets/profile_section_tile.dart';
import '../widgets/wifi_ble_setup_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _biometricEnabled = false;
  bool _criticalAlerts = true;
  bool _motorAlerts = true;

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
                        Text('My Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: c.textPrimary)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {},
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(color: c.surfaceElevated, borderRadius: BorderRadius.circular(12)),
                            child: Icon(Icons.edit_outlined, color: c.textSecondary, size: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Profile card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: c.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60, height: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [c.primary, c.primaryDark]),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                            child: const Text('NB', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Navin Bind', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
                              const SizedBox(height: 3),
                              Text('+91 93736 36122', style: TextStyle(fontSize: 13, color: c.textSecondary)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: c.orange.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('⭐', style: TextStyle(fontSize: 12)),
                                    const SizedBox(width: 4),
                                    Text('ADMIN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.orange, letterSpacing: 0.5)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SectionLabel(label: 'SOCIETY'),
                    const SizedBox(height: 10),
                    _SectionCard(children: [
                      ProfileSectionTile(
                        icon: Icon(Icons.apartment, color: c.textSecondary, size: 18),
                        title: 'Green Valley Society', subtitle: 'Kalyan, Maharashtra', onTap: () {},
                      ),
                      Divider(color: c.divider, height: 1, indent: 70),
                      ProfileSectionTile(
                        icon: Icon(Icons.group_outlined, color: c.textSecondary, size: 18),
                        title: 'Manage Members', subtitle: '4 members, 2 admins', onTap: () {},
                      ),
                    ]),
                    const SizedBox(height: 20),
                    // Appearance
                    _SectionLabel(label: 'APPEARANCE'),
                    const SizedBox(height: 10),
                    _SectionCard(children: [
                      BlocBuilder<ThemeCubit, ThemeMode>(
                        builder: (context, themeMode) {
                          final isDark = themeMode == ThemeMode.dark;
                          return ProfileSectionTile(
                            icon: Icon(
                              isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                              color: isDark ? c.primary : c.orange,
                              size: 20,
                            ),
                            title: 'Dark Mode',
                            subtitle: isDark ? 'Currently dark' : 'Currently light',
                            isSwitch: true,
                            switchValue: isDark,
                            onSwitchChanged: (_) => context.read<ThemeCubit>().toggle(),
                          );
                        },
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _SectionLabel(label: 'DEVICE SETUP'),
                    const SizedBox(height: 10),
                    _SectionCard(children: [
                      ProfileSectionTile(
                        icon: const Icon(Icons.bluetooth_rounded, color: Color(0xFF0A84FF), size: 20),
                        title: 'Connect via Bluetooth',
                        subtitle: 'Send Wi-Fi credentials to AquaControl-Setup',
                        onTap: () => WifiBleSetupSheet.show(context),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _SectionLabel(label: 'SECURITY'),
                    const SizedBox(height: 10),
                    _SectionCard(children: [
                      ProfileSectionTile(
                        icon: Icon(Icons.fingerprint, color: c.textSecondary, size: 20),
                        title: 'Biometric Login', subtitle: 'Fingerprint / Face ID',
                        isSwitch: true, switchValue: _biometricEnabled,
                        onSwitchChanged: (v) => setState(() => _biometricEnabled = v),
                      ),
                      Divider(color: c.divider, height: 1, indent: 70),
                      ProfileSectionTile(
                        icon: Icon(Icons.key_outlined, color: c.textSecondary, size: 18),
                        title: 'Change Password', onTap: () {},
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _SectionLabel(label: 'NOTIFICATIONS'),
                    const SizedBox(height: 10),
                    _SectionCard(children: [
                      ProfileSectionTile(
                        icon: Icon(Icons.warning_amber_rounded, color: c.red, size: 18),
                        title: 'Critical Alerts', subtitle: 'Dry run, overflow, fault',
                        isSwitch: true, switchValue: _criticalAlerts,
                        onSwitchChanged: (v) => setState(() => _criticalAlerts = v),
                      ),
                      Divider(color: c.divider, height: 1, indent: 70),
                      ProfileSectionTile(
                        icon: Icon(Icons.notifications_outlined, color: c.textSecondary, size: 18),
                        title: 'Motor Status Alerts', subtitle: 'On / Off notifications',
                        isSwitch: true, switchValue: _motorAlerts,
                        onSwitchChanged: (v) => setState(() => _motorAlerts = v),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    // Logout
                    GestureDetector(
                      onTap: () {
                        context.read<AuthBloc>().add(const LogoutRequested());
                        context.go('/login');
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: c.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: c.red.withValues(alpha: 0.3)),
                        ),
                        alignment: Alignment.center,
                        child: Text('Log Out', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.red)),
                      ),
                    ),
                    const SizedBox(height: 32),
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

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textLabel, letterSpacing: 1.2));
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(children: children),
    );
  }
}
