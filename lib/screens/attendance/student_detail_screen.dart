import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/attendance_record.dart';
import '../../models/student.dart';
import '../../services/attendance_api.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_app_bar.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/app_error_view.dart';


class StudentDetailScreen extends StatefulWidget {
  const StudentDetailScreen({super.key, required this.student});

  final Student student;

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  bool _loading = true;
  String? _error;

  int _attendancePercent = 0;
  int _presentCount = 0;
  int _absentCount = 0;
  int _lateCount = 0;

  Map<String, List<AttendanceRecord>> _groupedHistory = {};

  @override
  void initState() {
    super.initState();
    _fetchAttendanceHistory();
  }
  Future<void> _fetchAttendanceHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final records = await AttendanceApi.fetchUserAttendance(
        userId: widget.student.id,
      );

      // Deduplicate records by calendar day (yyyy-MM-dd)
      final Map<String, AttendanceRecord> uniqueDays = {};
      for (final r in records) {
        final dayKey = DateFormat('yyyy-MM-dd').format(r.date);
        final existing = uniqueDays[dayKey];
        if (existing == null) {
          uniqueDays[dayKey] = r;
        } else {
          // Resolve duplicate days by preferring the "better" status
          // present / working > late > absent
          if (r.status == AttendanceStatus.present || r.status == AttendanceStatus.working) {
            uniqueDays[dayKey] = r;
          } else if (r.status == AttendanceStatus.late && existing.status == AttendanceStatus.absent) {
            uniqueDays[dayKey] = r;
          }
        }
      }

      final uniqueRecords = uniqueDays.values.toList();

      // Calculate statistics dynamically
      int present = 0;
      int absent = 0;
      int late = 0;
      for (final r in uniqueRecords) {
        if (r.status == AttendanceStatus.present || r.status == AttendanceStatus.working) {
          present++;
        } else if (r.status == AttendanceStatus.absent) {
          absent++;
        } else if (r.status == AttendanceStatus.late) {
          late++;
        }
      }

      final total = present + absent + late;
      final percent = total > 0 ? ((present + late) * 100 ~/ total) : 0;

      // Sort unique records by date descending
      uniqueRecords.sort((a, b) => b.date.compareTo(a.date));

      // Group records by month (e.g. "May 2026")
      final Map<String, List<AttendanceRecord>> grouped = {};
      for (final r in uniqueRecords) {
        final monthStr = DateFormat('MMMM yyyy').format(r.date);
        grouped.putIfAbsent(monthStr, () => []).add(r);
      }

      if (mounted) {
        setState(() {
          _presentCount = present;
          _absentCount = absent;
          _lateCount = late;
          _attendancePercent = percent;
          _groupedHistory = grouped;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
        AppErrorView.show(context, e.toString(), onRetry: _fetchAttendanceHistory);
      }
    }
  }

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
                  UserAvatar(name: widget.student.name, size: 80),
                  const SizedBox(height: 12),
                  Text(widget.student.name, style: AppTextStyles.title),
                  const SizedBox(height: 4),
// Subtitle removed
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_loading) ...[
              const SizedBox(height: 64),
              const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ] else if (_error != null) ...[
              AppErrorView(
                error: _error!,
                title: 'Failed to load attendance history',
                onRetry: _fetchAttendanceHistory,
              ),
            ] else ...[
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
                              value: _attendancePercent / 100,
                              strokeWidth: 6,
                              backgroundColor: AppColors.surfaceAlt,
                              valueColor: const AlwaysStoppedAnimation(
                                  AppColors.primary),
                            ),
                          ),
                          Text('$_attendancePercent%',
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
                  _statTile('Present', _presentCount, AppColors.success),
                  const SizedBox(width: 12),
                  _statTile('Absent', _absentCount, AppColors.danger),
                  const SizedBox(width: 12),
                  _statTile('Late', _lateCount, AppColors.warning),
                ],
              ),
              const SizedBox(height: 24),
              Text('Attendance history', style: AppTextStyles.sectionTitle),
              const SizedBox(height: 12),
              if (_groupedHistory.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No attendance records found.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                for (final entry in _groupedHistory.entries) ...[
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
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat('EEE, d MMM')
                                          .format(entry.value[i].date),
                                      style: AppTextStyles.bodyStrong,
                                    ),
                                    if (entry.value[i].timeIn != null ||
                                        entry.value[i].timeOut != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          'In: ${entry.value[i].timeIn != null ? DateFormat.jm().format(entry.value[i].timeIn!) : '--'} • Out: ${entry.value[i].timeOut != null ? DateFormat.jm().format(entry.value[i].timeOut!) : '--'}',
                                          style: AppTextStyles.caption.copyWith(fontSize: 12),
                                        ),
                                      ),
                                  ],
                                ),
                                StatusPill(
                                  label: entry.value[i].status.label,
                                  type: switch (entry.value[i].status) {
                                    AttendanceStatus.present =>
                                      StatusPillType.success,
                                    AttendanceStatus.late =>
                                      StatusPillType.warning,
                                    AttendanceStatus.absent =>
                                      StatusPillType.danger,
                                    AttendanceStatus.working =>
                                      StatusPillType.info,
                                  },
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
