import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/activity_model.dart';
import '../widgets/history_event_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _showTodayOnly = false;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final all = ActivityModel.mockList;
    final today = DateTime.now();
    final filtered = _showTodayOnly
        ? all.where((a) => a.timestamp.year == today.year && a.timestamp.month == today.month && a.timestamp.day == today.day).toList()
        : all;

    final Map<String, List<ActivityModel>> grouped = {};
    for (final a in filtered) {
      grouped.putIfAbsent(_dateKey(a.timestamp), () => []).add(a);
    }

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    Text('Activity History', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: c.textPrimary)),
                    const Spacer(),
                    _FilterChip(label: 'Today', selected: _showTodayOnly,  onTap: () => setState(() => _showTodayOnly = true)),
                    const SizedBox(width: 8),
                    _FilterChip(label: 'All',   selected: !_showTodayOnly, onTap: () => setState(() => _showTodayOnly = false)),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final keys = grouped.keys.toList();
                  final key = keys[index];
                  final events = grouped[key]!;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(key.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textLabel, letterSpacing: 1.2)),
                        const SizedBox(height: 12),
                        ...events.map((e) => Padding(padding: const EdgeInsets.only(bottom: 10), child: HistoryEventCard(activity: e))),
                      ],
                    ),
                  );
                },
                childCount: grouped.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  String _dateKey(DateTime dt) {
    final now = DateTime.now();
    final todayD = DateTime(now.year, now.month, now.day);
    final yesterday = todayD.subtract(const Duration(days: 1));
    final date = DateTime(dt.year, dt.month, dt.day);
    if (date == todayD)   return 'Today — ${DateFormat('dd MMM yyyy').format(dt)}';
    if (date == yesterday) return 'Yesterday — ${DateFormat('dd MMM').format(dt)}';
    return DateFormat('EEEE — dd MMM').format(dt);
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.surfaceElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c.primary : c.cardBorder),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? c.primary : c.textMuted)),
      ),
    );
  }
}
