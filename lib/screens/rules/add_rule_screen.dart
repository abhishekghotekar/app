import 'package:flutter/material.dart';
import '../../theme/app_icons.dart';

import '../../models/rule.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_app_bar.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';

class AddRuleScreen extends StatefulWidget {
  const AddRuleScreen({super.key, this.rule});

  final Rule? rule;

  @override
  State<AddRuleScreen> createState() => _AddRuleScreenState();
}

class _AddRuleScreenState extends State<AddRuleScreen> {
  late final _name = TextEditingController(text: widget.rule?.name ?? '');
  final _phone = TextEditingController();
  late final _message = TextEditingController();
  late String _type = widget.rule?.type ?? 'Time-based';
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 15);
  String _target = 'All students';
  late Set<String> _recipients = {...?widget.rule?.recipients};
  late Set<String> _channels = {...?widget.rule?.channels};

  static const _types = ['Time-based', 'Event-based'];
  static const _targets = [
    'All students',
    'Class 10A',
    'Class 12A',
    'Class 12B',
  ];
  static const _allRecipients = ['Warden', 'Admin', 'Class teacher'];
  static const _allChannels = ['WhatsApp', 'Email', 'Push'];

  bool get _isEdit => widget.rule != null;

  @override
  void initState() {
    super.initState();
    if (_recipients.isEmpty) _recipients = {'Admin'};
    if (_channels.isEmpty) _channels = {'Push'};
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _save() {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isEdit ? 'Rule updated.' : 'Rule created.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppAppBar(
        title: _isEdit ? 'Edit Rule' : 'Add Rule',
        showBack: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                label: 'Rule Name',
                hint: 'e.g. Notify warden of absentees',
                controller: _name,
              ),
              const SizedBox(height: 24),
              _sectionLabel('TRIGGER'),
              const SizedBox(height: 8),
              _dropdown(
                value: _type,
                items: _types,
                onChanged: (v) => setState(() => _type = v),
              ),
              if (_type == 'Time-based') ...[
                const SizedBox(height: 12),
                _pickerRow(
                  icon: LucideIcons.clock,
                  label: 'Time',
                  value: _time.format(context),
                  onTap: _pickTime,
                ),
              ],
              const SizedBox(height: 24),
              _sectionLabel('CONDITION'),
              const SizedBox(height: 8),
              _dropdown(
                value: _target,
                items: _targets,
                onChanged: (v) => setState(() => _target = v),
              ),
              const SizedBox(height: 24),
              _sectionLabel('ACTION'),
              const SizedBox(height: 8),
              Text('Send to', style: AppTextStyles.caption),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in _allRecipients)
                    _selectChip(
                      r,
                      _recipients.contains(r),
                      () => setState(
                        () => _recipients.contains(r)
                            ? _recipients.remove(r)
                            : _recipients.add(r),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Channels', style: AppTextStyles.caption),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in _allChannels)
                    _selectChip(
                      c,
                      _channels.contains(c),
                      () => setState(
                        () => _channels.contains(c)
                            ? _channels.remove(c)
                            : _channels.add(c),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Phone number',
                hint: '+91 ',
                prefixIcon: LucideIcons.phone,
                controller: _phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Custom message (optional)',
                hint: 'Add a note included with the alert…',
                controller: _message,
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              PrimaryButton(label: 'Save Rule', onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text, style: AppTextStyles.label);

  Widget _dropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
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
          icon: const Icon(
            LucideIcons.chevronDown,
            size: 18,
            color: AppColors.textSecondary,
          ),
          style: AppTextStyles.body,
          borderRadius: BorderRadius.circular(8),
          items: [
            for (final i in items) DropdownMenuItem(value: i, child: Text(i)),
          ],
          onChanged: (v) => v == null ? null : onChanged(v),
        ),
      ),
    );
  }

  Widget _pickerRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(label, style: AppTextStyles.body),
          const Spacer(),
          Text(value, style: AppTextStyles.bodyStrong),
          const SizedBox(width: 6),
          const Icon(
            LucideIcons.chevronRight,
            size: 16,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _selectChip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.infoBg : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? LucideIcons.check : LucideIcons.plus,
              size: 14,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
