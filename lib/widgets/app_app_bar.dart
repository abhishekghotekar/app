import 'package:flutter/material.dart';
import '../theme/app_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Shared app bar. Supports an optional back button, a notification bell
/// with a red-dot badge, and arbitrary trailing actions.
class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppAppBar({
    super.key,
    required this.title,
    this.showBack = false,
    this.showBell = false,
    this.onBellTap,
    this.bellHasBadge = true,
    this.actions,
  });

  final String title;
  final bool showBack;
  final bool showBell;
  final VoidCallback? onBellTap;
  final bool bellHasBadge;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: showBack ? 0 : 20,
      leading: showBack
          ? IconButton(
              icon: const Icon(LucideIcons.arrowLeft),
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : null,
      title: Text(title, style: AppTextStyles.title),
      actions: [
        ...?actions,
        if (showBell)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _BellButton(
              onTap: onBellTap,
              hasBadge: bellHasBadge,
            ),
          ),
      ],
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.onTap, required this.hasBadge});

  final VoidCallback? onTap;
  final bool hasBadge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(LucideIcons.bell, size: 21),
            if (hasBadge)
              Positioned(
                right: -1,
                top: -1,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
