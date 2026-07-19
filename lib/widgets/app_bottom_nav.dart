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

/// Premium floating bottom navigation bar with responsive sizes and animated transitions.
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
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 360;

    // Responsive margins and padding
    final double outerPaddingH = isSmallScreen ? 8.0 : 16.0;
    final double outerPaddingBottom = isSmallScreen ? 8.0 : 12.0;
    final double outerPaddingTop = isSmallScreen ? 2.0 : 4.0;
    final double barHeight = isSmallScreen ? 68.0 : 78.0; // Increased

    return Container(
      padding: EdgeInsets.only(
        left: outerPaddingH,
        right: outerPaddingH,
        bottom: outerPaddingBottom,
        top: outerPaddingTop,
      ),
      decoration: const BoxDecoration(
        color: Colors.transparent, // Let Scaffold background show through margins
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: barHeight,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.8),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Row(
              children: [
                for (var i = 0; i < kBottomNavItems.length; i++)
                  Expanded(
                    child: _NavTab(
                      item: kBottomNavItems[i],
                      selected: i == currentIndex,
                      onTap: () => onTap(i),
                      isSmallScreen: isSmallScreen,
                    ),
                  ),
              ],
            ),
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
    required this.isSmallScreen,
  });

  final BottomNavItem item;
  final bool selected;
  final VoidCallback onTap;
  final bool isSmallScreen;

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.primary;
    final inactiveColor = AppColors.textSecondary;

    // Responsive layout configuration
    final double iconSize = isSmallScreen ? 21.0 : 24.0; // Increased
    final double fontSize = isSmallScreen ? 9.5 : 11.0; // Increased
    final double pillWidth = isSmallScreen ? 48.0 : 56.0; // Increased
    final double pillHeight = isSmallScreen ? 28.0 : 32.0; // Increased
    final double pillBorderRadius = isSmallScreen ? 14.0 : 16.0; // Increased
    final double dotSize = isSmallScreen ? 3.0 : 4.0;

    return InkWell(
      onTap: onTap,
      splashColor: activeColor.withValues(alpha: 0.05),
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 4),
          Stack(
            alignment: Alignment.center,
            children: [
              // Smooth background active pill expansion
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                width: selected ? pillWidth : 0,
                height: pillHeight,
                decoration: BoxDecoration(
                  color: selected
                      ? activeColor.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(pillBorderRadius),
                ),
              ),
              // Scale animated icon
              AnimatedScale(
                scale: selected ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                child: Icon(
                  item.icon,
                  size: iconSize,
                  color: selected ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Animated label style with scale-down fitting to prevent overflow
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: AppTextStyles.label.copyWith(
                    color: selected ? activeColor : inactiveColor,
                    fontSize: fontSize,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                  child: Text(item.label),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          // Mini active dot indicator below the label
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: selected ? dotSize : 0,
            height: dotSize,
            decoration: BoxDecoration(
              color: activeColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
