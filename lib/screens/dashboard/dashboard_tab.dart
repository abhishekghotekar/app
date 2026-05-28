import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_icons.dart';

import '../../data/mock_data.dart';
import '../../models/alert.dart';
import '../../models/attendance_record.dart';
import '../../services/attendance_api.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/user_avatar.dart';
import '../rules/alert_history_screen.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  late final List<Alert> _activeAlerts =
      MockData.alerts.where((a) => a.type != AlertType.summary).take(2).toList();

  List<AttendanceRecord> _records = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await AttendanceApi.fetchAttendance(date: DateTime.now());
      if (mounted) {
        setState(() {
          _records = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 12),
            Text('Loading dashboard...', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.circleAlert, color: AppColors.danger, size: 36),
              const SizedBox(height: 12),
              Text(
                _error!,
                style: AppTextStyles.caption.copyWith(color: AppColors.danger),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _fetchData,
                icon: const Icon(LucideIcons.refreshCw, size: 14),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final recentActivity = _records
        .where((r) => r.timeIn != null)
        .toList()
        ..sort((a, b) => b.timeIn!.compareTo(a.timeIn!));
    final recentCount = recentActivity.take(5).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        _greetingCard(),
        const SizedBox(height: 24),
        _quickStats(),
        const SizedBox(height: 24),
        _chartCard(),
        const SizedBox(height: 24),
        _deviceCard(),
        const SizedBox(height: 24),
        SectionHeader(
          title: 'Recent activity',
          actionLabel: 'See all',
          onAction: () {},
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: EdgeInsets.zero,
          child: recentCount.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No check-ins today yet.'),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < recentCount.length; i++) ...[
                      if (i > 0) const Divider(),
                      _activityRow(recentCount[i]),
                    ],
                  ],
                ),
        ),
        if (_activeAlerts.isNotEmpty) ...[
          const SizedBox(height: 24),
          SectionHeader(
            title: 'Active alerts',
            actionLabel: 'View all',
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AlertHistoryScreen()),
            ),
          ),
          const SizedBox(height: 12),
          ..._activeAlerts.map(_alertCard),
        ],
      ],
    );
  }

  Widget _greetingCard() {
    final hour = DateTime.now().hour;
    final part = hour < 12
        ? 'morning'
        : hour < 17
            ? 'afternoon'
            : 'evening';
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Good $part, Rahul 👋', style: AppTextStyles.title),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, d MMMM y').format(DateTime.now()),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const UserAvatar(name: 'Rahul Sharma'),
        ],
      ),
    );
  }

  Widget _quickStats() {
    final presentToday = _records
        .where((r) => r.status == AttendanceStatus.present || r.status == AttendanceStatus.late || r.status == AttendanceStatus.working)
        .length;
    final absentToday = _records.where((r) => r.status == AttendanceStatus.absent).length;
    final lateToday = _records.where((r) => r.status == AttendanceStatus.late).length;
    final totalPeople = _records.length;

    final stats = [
      _Stat('Present Today', '$presentToday', AppColors.success,
          'Active check-ins'),
      _Stat('Absent', '$absentToday', AppColors.danger,
          'Not checked in'),
      _Stat('Late', '$lateToday', AppColors.warning,
          'Checked in late'),
      _Stat('Total', '$totalPeople', AppColors.primary,
          'Total members'),
    ];
    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stats.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final s = stats[i];
          return SizedBox(
            width: 160,
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(s.label.toUpperCase(), style: AppTextStyles.label),
                  Text(s.value,
                      style:
                          AppTextStyles.statNumber.copyWith(color: s.color)),
                  Text(s.trend,
                      style: AppTextStyles.caption.copyWith(fontSize: 11)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _chartCard() {
    const labels = [
      '7a', '8a', '9a', '10a', '11a', '12p',
      '1p', '2p', '3p', '4p', '5p', '6p',
    ];
    final spots = [
      for (var i = 0; i < MockData.hourlyAttendance.length; i++)
        FlSpot(i.toDouble(), MockData.hourlyAttendance[i]),
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Today's attendance", style: AppTextStyles.sectionTitle),
          const SizedBox(height: 4),
          Text('Check-ins per hour', style: AppTextStyles.caption),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 80,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppColors.divider,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 20,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: AppTextStyles.caption.copyWith(fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 22,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            labels[i],
                            style:
                                AppTextStyles.caption.copyWith(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppColors.primary,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.22),
                          AppColors.primary.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
                lineTouchData: const LineTouchData(enabled: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _deviceCard() {
    final d = MockData.device;
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.infoBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.cpu,
                size: 22, color: AppColors.info),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.name, style: AppTextStyles.bodyStrong),
                const SizedBox(height: 2),
                Text(
                  'Last sync ${d.lastSync} · ${d.activeCameras} cameras active',
                  style: AppTextStyles.caption.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
          const StatusPill(label: 'Online', type: StatusPillType.success),
        ],
      ),
    );
  }

  Widget _activityRow(AttendanceRecord r) {
    final time = r.timeIn == null
        ? '—'
        : DateFormat('h:mm a').format(r.timeIn!);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          UserAvatar(name: r.studentName, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.studentName, style: AppTextStyles.bodyStrong),
                const SizedBox(height: 2),
                Text('Marked ${r.status.label.toLowerCase()} at $time',
                    style: AppTextStyles.caption.copyWith(fontSize: 11.5)),
              ],
            ),
          ),
          StatusPill(
            label: r.status.label,
            type: r.status == AttendanceStatus.present
                ? StatusPillType.success
                : r.status == AttendanceStatus.late
                    ? StatusPillType.warning
                    : r.status == AttendanceStatus.absent
                        ? StatusPillType.danger
                        : StatusPillType.info,
          ),
        ],
      ),
    );
  }

  Widget _alertCard(Alert a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: a.bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(a.icon, size: 18, color: a.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.title, style: AppTextStyles.bodyStrong),
                  const SizedBox(height: 2),
                  Text(a.body,
                      style: AppTextStyles.caption.copyWith(height: 1.4)),
                  const SizedBox(height: 4),
                  Text(DateFormat('h:mm a').format(a.time),
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      )),
                ],
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(LucideIcons.x,
                  size: 16, color: AppColors.textMuted),
              onPressed: () =>
                  setState(() => _activeAlerts.remove(a)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat {
  const _Stat(this.label, this.value, this.color, this.trend);
  final String label;
  final String value;
  final Color color;
  final String trend;
}
