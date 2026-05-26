import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import 'ghost_button.dart';

/// Section title with an optional trailing action link.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.sectionTitle),
        if (actionLabel != null && onAction != null)
          GhostButton(label: actionLabel!, onPressed: onAction),
      ],
    );
  }
}
