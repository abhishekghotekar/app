import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_icons.dart';

import '../../data/mock_data.dart';
import '../../models/alert.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_app_bar.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';

class AlertHistoryScreen extends StatefulWidget {
  const AlertHistoryScreen({super.key});

  @override
  State<AlertHistoryScreen> createState() => _AlertHistoryScreenState();
}

class _AlertHistoryScreenState extends State<AlertHistoryScreen> {
  int _filter = 0; // 0 All, 1 Today, 2 This week
  static const _filters = ['All', 'Today', 'This week'];

  List<Alert> get _filtered {
    final now = DateTime.now();
    return MockData.alerts.where((a) {
      switch (_filter) {
        case 1:
          return a.time.year == now.year &&
              a.time.month == now.month &&
              a.time.day == now.day;
        case 2:
          return now.difference(a.time).inDays < 7;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final alerts = _filtered;
    return Scaffold(
      appBar: const AppAppBar(title: 'Alert History', showBack: true),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                children: [
                  for (var i = 0; i < _filters.length; i++) ...[
                    _chip(_filters[i], i),
                    if (i < _filters.length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            Expanded(
              child: alerts.isEmpty
                  ? const EmptyState(
                      icon: LucideIcons.bellOff,
                      title: 'No alerts',
                      subtitle: 'Nothing matches this filter yet.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      itemCount: alerts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _alertCard(alerts[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, int index) {
    final selected = _filter == index;
    return InkWell(
      onTap: () => setState(() => _filter = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _alertCard(Alert a) {
    final now = DateTime.now();
    final sameDay = a.time.year == now.year &&
        a.time.month == now.month &&
        a.time.day == now.day;
    final stamp = sameDay
        ? DateFormat('h:mm a').format(a.time)
        : DateFormat('d MMM, h:mm a').format(a.time);
    return AppCard(
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
                Text(stamp,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
