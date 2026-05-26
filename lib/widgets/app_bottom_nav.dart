import 'package:flutter/material.dart';
import '../theme/app_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class BottomNavItem {
  const BottomNavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

const kBottomNavItems = <BottomNavItem>[
  BottomNavItem(LucideIcons.layoutDashboard, 'Dashboard'),
  BottomNavItem(LucideIcons.userCheck, 'Attendance'),
  BottomNavItem(LucideIcons.video, 'Cameras'),
  BottomNavItem(LucideIcons.users, 'Users'),
  BottomNavItem(LucideIcons.settings, 'Settings'),
];

/// White bottom navigation bar with a 1px top border, no FAB.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < kBottomNavItems.length; i++)
                Expanded(
                  child: _NavTab(
                    item: kBottomNavItems[i],
                    selected: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final BottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, size: 21, color: color),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: AppTextStyles.label.copyWith(
              color: color,
              fontSize: 11,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
