import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';

class MainScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const MainScreen({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.background,
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.cardBorder, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                _NavItem(icon: Icons.home_outlined,      activeIcon: Icons.home,        label: 'HOME',    selected: navigationShell.currentIndex == 0, onTap: () => navigationShell.goBranch(0)),
                _NavItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart,   label: 'DEVICES', selected: navigationShell.currentIndex == 1, onTap: () => navigationShell.goBranch(1)),
                _NavItem(icon: Icons.assignment_outlined,activeIcon: Icons.assignment,  label: 'HISTORY', selected: navigationShell.currentIndex == 2, onTap: () => navigationShell.goBranch(2)),
                _NavItem(icon: Icons.person_outline,     activeIcon: Icons.person,      label: 'PROFILE', selected: navigationShell.currentIndex == 3, onTap: () => navigationShell.goBranch(3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: selected ? c.primary.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(selected ? activeIcon : icon, color: selected ? c.primary : c.textMuted, size: 22),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: selected ? c.primary : c.textMuted, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}
