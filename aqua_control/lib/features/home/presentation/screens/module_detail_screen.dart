import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../devices/data/models/device_model.dart';
import '../../../devices/data/models/device_info_model.dart';
import '../../../devices/data/repositories/device_repository.dart';
import '../../../profile/data/repositories/society_repository.dart';
import '../../data/models/pump_status_model.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import '../widgets/voltage_current_card.dart';
import '../widgets/pump_control_card.dart';

class ModuleDetailScreen extends StatelessWidget {
  final DeviceModel device;
  const ModuleDetailScreen({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final userName = authState is AuthAuthenticated ? authState.user.name : '';
    final userId = authState is AuthAuthenticated ? authState.user.id : '';
    final societyCode =
        authState is AuthAuthenticated ? authState.user.societyCode : '';
    return BlocProvider(
      create: (_) => HomeBloc()
        ..add(LoadHomeData(
          userName: userName,
          productCode: device.productCode,
          societyCode: societyCode,
          commandBy: userId,
        )),
      child: _ModuleDetailView(device: device),
    );
  }
}

class _ModuleDetailView extends StatefulWidget {
  final DeviceModel device;
  const _ModuleDetailView({required this.device});

  @override
  State<_ModuleDetailView> createState() => _ModuleDetailViewState();
}

class _ModuleDetailViewState extends State<_ModuleDetailView> {
  final _societyRepo = SocietyRepository();
  DeviceInfoModel? _info;
  bool _infoLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    setState(() => _infoLoading = true);
    try {
      final info = await context
          .read<DeviceRepository>()
          .fetchDeviceInfo(widget.device.productCode);
      if (mounted)
        setState(() {
          _info = info;
          _infoLoading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _infoLoading = false);
    }
  }

  String _alertMessage(PumpStatusModel status) {
    if (status.ocBreached && status.ucBreached) {
      return 'Overcurrent & undercurrent detected';
    }
    if (status.ocBreached) return 'Overcurrent detected';
    return 'Undercurrent detected';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final authState = context.read<AuthBloc>().state;
    final currentUserId =
        authState is AuthAuthenticated ? authState.user.id : '';
    final societyId =
        authState is AuthAuthenticated ? authState.user.societyId : '';
    final currentMember =
        _info?.members.where((m) => m.userId == currentUserId).firstOrNull;
    // Use freshly-fetched member role; fall back to DeviceModel only before info loads
    final isAdmin = currentMember?.isAdmin ?? widget.device.isAdmin;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: c.surfaceElevated,
                borderRadius: BorderRadius.circular(10)),
            child:
                Icon(Icons.arrow_back_ios_new, size: 16, color: c.textPrimary),
          ),
        ),
        title: Text('All modules',
            style: TextStyle(fontSize: 14, color: c.textSecondary)),
      ),
      body: SafeArea(
        top: false,
        child: MultiBlocListener(
          listeners: [
            BlocListener<HomeBloc, HomeState>(
              listenWhen: (_, curr) =>
                  curr is HomeLoaded && curr.motorError != null,
              listener: (context, state) {
                if (state is! HomeLoaded || state.motorError == null) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Motor command failed: ${state.motorError}'),
                  backgroundColor: c.red,
                  behavior: SnackBarBehavior.floating,
                ));
              },
            ),
            BlocListener<HomeBloc, HomeState>(
              // Rising edge only — fire once when a breach first appears, not on every poll while it's still active.
              listenWhen: (prev, curr) {
                if (curr is! HomeLoaded) return false;
                final wasActive =
                    prev is HomeLoaded ? prev.status.hasActiveAlert : false;
                return !wasActive && curr.status.hasActiveAlert;
              },
              listener: (context, state) {
                final status = (state as HomeLoaded).status;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      '⚠️ ${_alertMessage(status)} on ${widget.device.productCode}'),
                  backgroundColor: c.red,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 6),
                ));
              },
            ),
          ],
          child: BlocBuilder<HomeBloc, HomeState>(
            builder: (context, state) {
              final loaded = state is HomeLoaded ? state : null;

              return RefreshIndicator(
                color: c.primary,
                backgroundColor: c.surface,
                onRefresh: () async {
                  final bloc = context.read<HomeBloc>();
                  // add() alone doesn't wait for the handler to finish, so
                  // the RefreshIndicator's spinner used to dismiss before
                  // the status fetch even completed — wait for the next
                  // HomeLoaded emission instead, same as a fresh LoadHomeData.
                  final statusRefreshed =
                      bloc.stream.firstWhere((s) => s is HomeLoaded);
                  bloc.add(const RefreshStatus(force: true));
                  await Future.wait([statusRefreshed, _loadInfo()]);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header ──────────────────────────────────────
                      Text(
                        widget.device.displayName,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.device.productCode,
                        style: TextStyle(
                            fontSize: 12.5,
                            color: c.textMuted,
                            fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 4),
                      if (_info?.module != null)
                        Text(
                          '${_info!.module!.noOfPump} pump${_info!.module!.noOfPump > 1 ? 's' : ''} · ${_info!.module!.phase} · ${_info!.module!.hpOfPump} HP',
                          style:
                              TextStyle(fontSize: 13, color: c.textSecondary),
                        ),
                      const SizedBox(height: 12),

                      // ── Active alert banner ───────────────────────
                      if (loaded != null && loaded.status.hasActiveAlert) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: c.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: c.red.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: c.red, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _alertMessage(loaded.status),
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: c.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Address info ──────────────────────────────
                      if (_info?.module != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: c.cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _InfoRow(
                                icon: Icons.location_on_outlined,
                                label: 'Address',
                                value: [
                                  _info!.module!.address,
                                  _info!.module!.wingBlock
                                ].where((s) => s.isNotEmpty).join(', '),
                                colors: c,
                              ),
                              if (_info!.module!.district.isNotEmpty) ...[
                                Divider(color: c.divider, height: 20),
                                _InfoRow(
                                  icon: Icons.map_outlined,
                                  label: 'Location',
                                  value:
                                      '${_info!.module!.district}, ${_info!.module!.state} – ${_info!.module!.pincode}',
                                  colors: c,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Volt / Current stat cards ─────────────────
                      Row(
                        children: [
                          VoltageCurrentCard(
                            label: 'VOLTAGE',
                            value: loaded != null
                                ? loaded.status.voltage.round().toString()
                                : '—',
                            unit: 'V',
                            subtitle: 'Normal range',
                            emoji: '⚡',
                            valueColor: c.green,
                          ),
                          const SizedBox(width: 12),
                          VoltageCurrentCard(
                            label: 'CURRENT',
                            value: loaded != null
                                ? loaded.status.current.toStringAsFixed(1)
                                : '—',
                            unit: 'A',
                            subtitle: loaded != null
                                ? (loaded.status.motorStatus.name == 'on'
                                    ? 'Motor running'
                                    : 'Motor idle')
                                : '—',
                            emoji: '🌊',
                            valueColor: c.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Pump control ──────────────────────────────
                      if (loaded != null)
                        PumpControlCard(
                          status: loaded.status,
                          commandPending: loaded.commandPending,
                        )
                      else
                        Container(
                          height: 80,
                          decoration: BoxDecoration(
                              color: c.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: c.cardBorder)),
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: c.primary, strokeWidth: 2)),
                        ),
                      const SizedBox(height: 16),

                      // ── Members panel ─────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: c.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.group_rounded,
                                    color: c.textSecondary, size: 18),
                                const SizedBox(width: 8),
                                Text('Members',
                                    style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: c.textPrimary)),
                                const Spacer(),
                                if (isAdmin)
                                  GestureDetector(
                                    onTap: () => _openAddMemberSheet(
                                        context, societyId, c),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: c.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: c.primary
                                                .withValues(alpha: 0.3)),
                                      ),
                                      child: Text('+ Add',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: c.primary)),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_infoLoading)
                              Center(
                                  child: SizedBox(
                                      height: 32,
                                      width: 32,
                                      child: CircularProgressIndicator(
                                          color: c.primary, strokeWidth: 2)))
                            else if (_info == null || _info!.members.isEmpty)
                              Center(
                                child: Text('No members yet',
                                    style: TextStyle(
                                        fontSize: 13, color: c.textMuted)),
                              )
                            else
                              ..._info!.members.asMap().entries.map((entry) {
                                final i = entry.key;
                                final m = entry.value;
                                return Column(
                                  children: [
                                    if (i > 0)
                                      Divider(color: c.divider, height: 1),
                                    _MemberRow(member: m, colors: c),
                                  ],
                                );
                              }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── History link ──────────────────────────────
                      GestureDetector(
                        onTap: () => context.push('/home/module-detail/history',
                            extra: widget.device.productCode),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: c.cardBorder),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: c.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: const Text('📋',
                                    style: TextStyle(fontSize: 18)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Activity history',
                                        style: TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w600,
                                            color: c.textPrimary)),
                                    const SizedBox(height: 2),
                                    Text(
                                        'Motor actions, threshold changes, members',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: c.textSecondary)),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right,
                                  color: c.textMuted, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _openAddMemberSheet(
      BuildContext context, String societyId, AppColorScheme c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMemberSheet(
        moduleName: widget.device.productCode,
        societyId: societyId,
        repo: _societyRepo,
        onAdded: _loadInfo,
      ),
    );
  }
}

// ─── Info row (address label + value) ────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final AppColorScheme colors;
  const _InfoRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: c.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: c.textMuted)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 13, color: c.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Member row ───────────────────────────────────────────────

class _MemberRow extends StatelessWidget {
  final DeviceMemberModel member;
  final AppColorScheme colors;
  const _MemberRow({required this.member, required this.colors});

  static const _avatarColors = [
    Color(0xFF4F7CFF),
    Color(0xFFF5B942),
    Color(0xFF4ADE80),
    Color(0xFFF87171),
    Color(0xFFA78BFA),
    Color(0xFF38BDF8),
  ];

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final roleColor = member.isAdmin ? const Color(0xFFFFB020) : c.primary;
    final last4 = member.phoneNumber.length >= 4
        ? member.phoneNumber.substring(member.phoneNumber.length - 4)
        : member.phoneNumber;
    final colorIdx = member.phoneNumber.codeUnits.fold(0, (a, b) => a + b) %
        _avatarColors.length;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // Avatar
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _avatarColors[colorIdx],
                  shape: BoxShape.circle,
                  border: member.isAdmin
                      ? Border.all(color: const Color(0xFFFFB020), width: 2)
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(last4,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              if (member.isAdmin)
                Positioned(
                  bottom: -3,
                  right: -3,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB020),
                      shape: BoxShape.circle,
                      border: Border.all(color: c.surface, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: const Text('♛',
                        style:
                            TextStyle(fontSize: 8, color: Color(0xFF1A1200))),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.phoneNumber,
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary)),
                const SizedBox(height: 2),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    member.role.toUpperCase(),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: roleColor,
                        letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Add member bottom sheet ──────────────────────────────────

class _AddMemberSheet extends StatefulWidget {
  final String moduleName;
  final String societyId;
  final SocietyRepository repo;
  final VoidCallback onAdded;

  const _AddMemberSheet({
    required this.moduleName,
    required this.societyId,
    required this.repo,
    required this.onAdded,
  });

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final _phoneCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  static String _toE164(String mobile) {
    final digits = mobile.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    return mobile;
  }

  Future<void> _add() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Enter a phone number');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.repo.addMember(
          societyId: widget.societyId,
          phoneNumber: _toE164(phone),
          productCode: widget.moduleName);
      if (mounted) {
        Navigator.pop(context);
        widget.onAdded();
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.cardBorder),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: c.divider, borderRadius: BorderRadius.circular(3)),
            ),
          ),
          const SizedBox(height: 18),
          Text('Add member',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary)),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 13, color: c.textSecondary),
              children: [
                const TextSpan(text: 'Give access to '),
                TextSpan(
                    text: widget.moduleName,
                    style: TextStyle(
                        color: c.textPrimary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Phone input styled as search bar
          Container(
            decoration: BoxDecoration(
              color: c.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.cardBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(Icons.phone_outlined, size: 16, color: c.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(fontSize: 14, color: c.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Phone number (e.g. 9876543210)',
                      hintStyle: TextStyle(color: c.textMuted, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.error_outline, size: 14, color: c.red),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(_error!,
                        style: TextStyle(fontSize: 12, color: c.red))),
              ],
            ),
          ],

          // Divider: or invite externally
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              children: [
                Expanded(child: Divider(color: c.divider)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or invite externally',
                      style: TextStyle(fontSize: 11.5, color: c.textMuted)),
                ),
                Expanded(child: Divider(color: c.divider)),
              ],
            ),
          ),

          // Invite buttons
          GestureDetector(
            onTap: () {},
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: c.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.cardBorder),
              ),
              alignment: Alignment.center,
              child: Text('🔗  Copy invite link',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary)),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: c.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.green.withValues(alpha: 0.3)),
              ),
              alignment: Alignment.center,
              child: Text('💬  Share via WhatsApp',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.green)),
            ),
          ),
          const SizedBox(height: 20),

          // Add button
          SizedBox(
            width: double.infinity,
            child: _loading
                ? Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: c.primary.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white)),
                  )
                : GestureDetector(
                    onTap: _add,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                          color: c.primary,
                          borderRadius: BorderRadius.circular(14)),
                      alignment: Alignment.center,
                      child: const Text('Add Member',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
