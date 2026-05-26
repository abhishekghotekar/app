import 'package:flutter/material.dart';
import '../theme/app_icons.dart';

import '../theme/app_colors.dart';

enum AlertType { absentee, lateArrival, deviceOffline, summary, intrusion }

/// A single alert / notification entry.
class Alert {
  const Alert({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.time,
  });

  final String id;
  final AlertType type;
  final String title;
  final String body;
  final DateTime time;

  IconData get icon {
    switch (type) {
      case AlertType.absentee:
        return LucideIcons.userX;
      case AlertType.lateArrival:
        return LucideIcons.clock;
      case AlertType.deviceOffline:
        return LucideIcons.wifiOff;
      case AlertType.summary:
        return LucideIcons.fileText;
      case AlertType.intrusion:
        return LucideIcons.shieldAlert;
    }
  }

  Color get color {
    switch (type) {
      case AlertType.absentee:
        return AppColors.danger;
      case AlertType.lateArrival:
        return AppColors.warning;
      case AlertType.deviceOffline:
        return AppColors.danger;
      case AlertType.summary:
        return AppColors.info;
      case AlertType.intrusion:
        return AppColors.warning;
    }
  }

  Color get bgColor {
    switch (type) {
      case AlertType.absentee:
      case AlertType.deviceOffline:
        return AppColors.dangerBg;
      case AlertType.lateArrival:
      case AlertType.intrusion:
        return AppColors.warningBg;
      case AlertType.summary:
        return AppColors.infoBg;
    }
  }
}
