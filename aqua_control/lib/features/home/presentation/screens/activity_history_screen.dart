import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../data/models/module_action_log_model.dart';
import '../../data/repositories/motor_repository.dart';

class ActivityHistoryScreen extends StatefulWidget {
  final String productCode;
  const ActivityHistoryScreen({super.key, required this.productCode});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  final _repo = MotorRepository();
  List<ModuleActionLogModel> _logs = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final logs = await _repo.fetchActionLogs(widget.productCode);
      if (mounted)
        setState(() {
          _logs = logs;
          _loading = false;
        });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
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
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: c.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Activity History',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: c.textPrimary)),
      ),
      body: _buildBody(c),
    );
  }

  Widget _buildBody(AppColorScheme c) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: c.primary));
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, color: c.red, size: 48),
              const SizedBox(height: 16),
              Text(_error,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.textSecondary, fontSize: 14)),
              const SizedBox(height: 24),
              CustomButton(label: 'Retry', onTap: _load),
            ],
          ),
        ),
      );
    }

    if (_logs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_rounded, color: c.textMuted, size: 64),
              const SizedBox(height: 16),
              Text('No activity yet',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary)),
              const SizedBox(height: 8),
              Text('Motor commands will show up here once triggered.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.textMuted, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: c.primary,
      backgroundColor: c.surface,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        itemCount: _logs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _LogCard(log: _logs[i], colors: c),
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final ModuleActionLogModel log;
  final AppColorScheme colors;
  const _LogCard({required this.log, required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final isOn = log.motorStatus == 'ON';
    final statusColor = isOn ? c.green : c.textMuted;
    final timestamp = log.createdAt != null
        ? DateFormat('MMM d, h:mm a').format(log.createdAt!.toLocal())
        : '—';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: log.hasBreach ? c.red.withValues(alpha: 0.4) : c.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isOn ? 'MOTOR ON' : 'MOTOR OFF',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                      letterSpacing: 0.4),
                ),
              ),
              if (log.hasBreach) ...[
                const SizedBox(width: 8),
                Icon(Icons.warning_amber_rounded, color: c.red, size: 14),
                const SizedBox(width: 3),
                Text(
                  log.ocBreached && log.ucBreached
                      ? 'OC & UC breach'
                      : log.ocBreached
                          ? 'OC breach'
                          : 'UC breach',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: c.red),
                ),
              ],
              const Spacer(),
              Text(timestamp,
                  style: TextStyle(fontSize: 12, color: c.textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatChip(
                  label: 'V', value: log.voltage.toStringAsFixed(0), colors: c),
              const SizedBox(width: 8),
              _StatChip(
                  label: 'A', value: log.current.toStringAsFixed(1), colors: c),
              const SizedBox(width: 8),
              _StatChip(
                  label: 'OH', value: '${log.overheadTankLevel}%', colors: c),
              const SizedBox(width: 8),
              _StatChip(
                  label: 'UG',
                  value: '${log.undergroundTankLevel}%',
                  colors: c),
            ],
          ),
          if (log.createdBy != null && log.createdBy!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('by ${log.createdBy}',
                style: TextStyle(fontSize: 11.5, color: c.textMuted)),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final AppColorScheme colors;
  const _StatChip(
      {required this.label, required this.value, required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
              text: '$label ',
              style: TextStyle(
                  fontSize: 10.5,
                  color: c.textMuted,
                  fontWeight: FontWeight.w600)),
          TextSpan(
              text: value,
              style: TextStyle(
                  fontSize: 12,
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
