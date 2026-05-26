import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_icons.dart';

import '../../data/mock_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_app_bar.dart';
import '../../widgets/app_card.dart';
import '../../widgets/ghost_button.dart';
import '../../widgets/primary_button.dart';


class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  DateTimeRange _range = DateTimeRange(
    start: MockData.today.subtract(const Duration(days: 6)),
    end: MockData.today,
  );
  String _format = 'CSV';
  final _includePhotos = ValueNotifier(false);
  final _includeLate = ValueNotifier(true);
  final _includeSummary = ValueNotifier(true);
  bool _exporting = false;

  @override
  void dispose() {
    _includePhotos.dispose();
    _includeLate.dispose();
    _includeSummary.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: DateTime(2025),
      lastDate: DateTime(2027),
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _exporting = false);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Report ready', style: AppTextStyles.title),
        content: Text(
          'Your $_format report has been generated.',
          style: AppTextStyles.body,
        ),
        actions: [
          GhostButton(
            label: 'Open',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          GhostButton(
            label: 'Share',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM y');
    return Scaffold(
      appBar: const AppAppBar(title: 'Export Report', showBack: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Date range', style: AppTextStyles.caption),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickRange,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.calendarRange,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        '${fmt.format(_range.start)}  –  ${fmt.format(_range.end)}',
                        style: AppTextStyles.body,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Format', style: AppTextStyles.caption),
              const SizedBox(height: 8),
              AppCard(
                padding: EdgeInsets.zero,
                child: RadioGroup<String>(
                  groupValue: _format,
                  onChanged: (v) => setState(() => _format = v!),
                  child: Column(
                    children: [
                      for (final f in const ['CSV', 'PDF', 'Excel']) ...[
                        if (f != 'CSV') const Divider(),
                        RadioListTile<String>(
                          value: f,
                          activeColor: AppColors.primary,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          title: Text(f, style: AppTextStyles.body),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Include', style: AppTextStyles.caption),
              const SizedBox(height: 8),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _checkRow('Student photos', _includePhotos),
                    const Divider(),
                    _checkRow('Late entries', _includeLate),
                    const Divider(),
                    _checkRow('Summary statistics', _includeSummary),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Export Report',
                icon: LucideIcons.download,
                loading: _exporting,
                onPressed: _export,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _checkRow(String label, ValueNotifier<bool> notifier) {
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (_, value, _) => CheckboxListTile(
        value: value,
        activeColor: AppColors.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(label, style: AppTextStyles.body),
        onChanged: (v) => notifier.value = v ?? false,
      ),
    );
  }
}
