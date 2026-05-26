import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// White surface card: 1px border, 12px radius, optional soft shadow and tap.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.elevated = false,
    this.margin,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool elevated;
  final EdgeInsetsGeometry? margin;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: borderColor ?? AppColors.border),
      boxShadow: elevated ? const [AppColors.cardShadow] : null,
    );

    if (onTap == null) {
      return Container(
        margin: margin,
        decoration: decoration,
        child: Padding(padding: padding, child: child),
      );
    }

    return Container(
      margin: margin,
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.surfaceAlt,
          highlightColor: AppColors.surfaceAlt,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
