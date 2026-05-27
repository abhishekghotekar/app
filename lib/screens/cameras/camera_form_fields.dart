import 'package:flutter/material.dart';
import '../../theme/app_icons.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Resolution picker shared by the add / settings camera screens.
class ResolutionDropdown extends StatelessWidget {
  const ResolutionDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  static const _options = ['720p', '768p', '1080p', '4K'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(LucideIcons.chevronDown,
              size: 18, color: AppColors.textSecondary),
          style: AppTextStyles.body,
          borderRadius: BorderRadius.circular(8),
          items: [
            for (final o in _options)
              DropdownMenuItem(value: o, child: Text(o)),
          ],
          onChanged: (v) => v == null ? null : onChanged(v),
        ),
      ),
    );
  }
}

/// Frame rate slider (1–30 fps) shared by the add / settings camera screens.
class FrameRateSlider extends StatelessWidget {
  const FrameRateSlider({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Frame Rate', style: AppTextStyles.caption),
            Text('${value.round()} fps', style: AppTextStyles.bodyStrong),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.border,
            thumbColor: AppColors.primary,
            overlayColor: AppColors.infoBg,
            trackHeight: 3,
          ),
          child: Slider(
            value: value,
            min: 1,
            max: 30,
            divisions: 29,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
