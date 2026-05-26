import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum StatusPillType { success, warning, danger, info, neutral }

/// Rounded-full tinted status pill: light background + colored text.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.type,
    this.dot = true,
  });

  final String label;
  final StatusPillType type;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: AppTextStyles.label.copyWith(
              color: fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color) _colors(StatusPillType type) {
    switch (type) {
      case StatusPillType.success:
        return (AppColors.successBg, AppColors.success);
      case StatusPillType.warning:
        return (AppColors.warningBg, AppColors.warning);
      case StatusPillType.danger:
        return (AppColors.dangerBg, AppColors.danger);
      case StatusPillType.info:
        return (AppColors.infoBg, AppColors.info);
      case StatusPillType.neutral:
        return (AppColors.surfaceAlt, AppColors.textSecondary);
    }
  }
}
