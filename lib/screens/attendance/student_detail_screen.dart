import 'package:flutter/material.dart';

import '../../models/student.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_app_bar.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/user_avatar.dart';

class StudentDetailScreen extends StatelessWidget {
  const StudentDetailScreen({super.key, required this.student});

  final Student student;


  /// Mock month-grouped attendance history.
  static const _history = <String, List<(String, StatusPillType)>>{
    'May 2026': [
      ('Mon, 12 May', StatusPillType.success),
      ('Tue, 13 May', StatusPillType.warning),
      ('Wed, 14 May', StatusPillType.success),
    ],
    'April 2026': [
      ('Mon, 28 Apr', StatusPillType.success),
      ('Tue, 29 Apr', StatusPillType.danger),
      ('Wed, 30 Apr', StatusPillType.success),
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppAppBar(title: 'Student Detail', showBack: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Center(
              child: Column(
                children: [
                  UserAvatar(name: student.name, size: 80),
                  const SizedBox(height: 12),
                  Text(student.name, style: AppTextStyles.title),
                  const SizedBox(height: 4),
                  Text(
                    '${student.rollNumber} · ${student.department}',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AppCard(
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: CircularProgressIndicator(
                            value: student.attendancePercent / 100,
                            strokeWidth: 6,
                            backgroundColor: AppColors.surfaceAlt,
                            valueColor: const AlwaysStoppedAnimation(
                                AppColors.primary),
                          ),
                        ),
                        Text('${student.attendancePercent}%',
                            style: AppTextStyles.bodyStrong),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Overall attendance',
                            style: AppTextStyles.bodyStrong),
                        const SizedBox(height: 2),
                        Text(
                          'Across all recorded sessions this year.',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _statTile('Present', student.presentCount, AppColors.success),
                const SizedBox(width: 12),
                _statTile('Absent', student.absentCount, AppColors.danger),
                const SizedBox(width: 12),
                _statTile('Late', student.lateCount, AppColors.warning),
              ],
            ),
            const SizedBox(height: 24),
            Text('Attendance history', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 12),
            for (final entry in _history.entries) ...[
              Text(entry.key.toUpperCase(), style: AppTextStyles.label),
              const SizedBox(height: 8),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < entry.value.length; i++) ...[
                      if (i > 0) const Divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.value[i].$1,
                                style: AppTextStyles.body),
                            StatusPill(
                              label: switch (entry.value[i].$2) {
                                StatusPillType.success => 'Present',
                                StatusPillType.warning => 'Late',
                                StatusPillType.danger => 'Absent',
                                _ => '—',
                              },
                              type: entry.value[i].$2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, int value, Color color) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Text('$value',
                style: AppTextStyles.statNumber
                    .copyWith(color: color, fontSize: 24)),
            const SizedBox(height: 2),
            Text(label.toUpperCase(), style: AppTextStyles.label),
          ],
        ),
      ),
    );
  }
}
