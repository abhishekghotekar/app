import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_icons.dart';

import '../../data/mock_data.dart';
import '../../models/attendance_record.dart';
import '../../models/student.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/user_avatar.dart';
import 'export_screen.dart';
import 'student_detail_screen.dart';



class AttendanceListScreen extends StatefulWidget {
  const AttendanceListScreen({super.key});

  @override
  State<AttendanceListScreen> createState() => _AttendanceListScreenState();
}

class _AttendanceListScreenState extends State<AttendanceListScreen> {
  DateTime _date = MockData.today;
  int _statusTab = 0; // 0 All, 1 Present, 2 Absent, 3 Late
  String _deptFilter = 'All';

  static const _tabs = ['All', 'Present', 'Absent', 'Late'];
  static const _depts = ['All', 'CSE', 'ECE', 'Mech', 'Faculty'];

  List<AttendanceRecord> get _filtered {
    return MockData.todayRecords.where((r) {
      final statusOk = switch (_statusTab) {
        1 => r.status == AttendanceStatus.present,
        2 => r.status == AttendanceStatus.absent,
        3 => r.status == AttendanceStatus.late,
        _ => true,
      };
      final deptOk = _deptFilter == 'All' || r.department == _deptFilter;
      return statusOk && deptOk;
    }).toList();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2025),
      lastDate: DateTime(2027),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final records = _filtered;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 11),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.calendar,
                                size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('EEE, d MMM y').format(_date),
                              style: AppTextStyles.body,
                            ),
                            const Spacer(),
                            const Icon(LucideIcons.chevronDown,
                                size: 16, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _iconButton(LucideIcons.download, () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ExportScreen()),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _depts.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _chip(
                    _depts[i],
                    _deptFilter == _depts[i],
                    () => setState(() => _deptFilter = _depts[i]),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++) ...[
                    _statusChip(_tabs[i], i),
                    if (i < _tabs.length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _refresh,
            child: records.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 80),
                      EmptyState(
                        icon: LucideIcons.userCheck,
                        title: 'No records',
                        subtitle: 'No attendance entries match these filters.',
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    itemCount: records.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _recordCard(records[i]),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String label, int index) {
    final selected = _statusTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _statusTab = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.infoBg : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: selected ? AppColors.primary : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _recordCard(AttendanceRecord r) {
    final time =
        r.timeIn == null ? '—' : DateFormat('h:mm a').format(r.timeIn!);
    return AppCard(
      onTap: () {
        final student = MockData.students.firstWhere(
          (s) => s.id == r.studentId,
          orElse: () => Student(
            id: r.studentId,
            name: r.studentName,
            rollNumber: r.rollNumber,
            department: r.department,
            className: '—',
            role: 'Student',
          ),
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StudentDetailScreen(student: student),
          ),
        );
      },
      child: Row(
        children: [
          UserAvatar(name: r.studentName, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.studentName, style: AppTextStyles.bodyStrong),
                const SizedBox(height: 2),
                Text('${r.rollNumber} · In: $time',
                    style: AppTextStyles.caption),
              ],
            ),
          ),
          StatusPill(
            label: r.status.label,
            type: switch (r.status) {
              AttendanceStatus.present => StatusPillType.success,
              AttendanceStatus.late => StatusPillType.warning,
              AttendanceStatus.absent => StatusPillType.danger,
            },
          ),
        ],
      ),
    );
  }
}
