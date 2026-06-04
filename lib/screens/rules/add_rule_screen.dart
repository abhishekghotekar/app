import 'package:flutter/material.dart';
import '../../theme/app_icons.dart';

import '../../models/whatsapp_rule.dart';
import '../../services/whatsapp_rules_api.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_app_bar.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';

/// Screen for creating a new WhatsApp rule or editing an existing one.
///
/// On save, pops and returns the [WhatsAppRule] that was created/updated.
class AddWhatsAppRuleScreen extends StatefulWidget {
  const AddWhatsAppRuleScreen({super.key, this.existingRule});

  /// Provide an existing rule to enter edit mode.
  final WhatsAppRule? existingRule;

  @override
  State<AddWhatsAppRuleScreen> createState() => _AddWhatsAppRuleScreenState();
}

class _AddWhatsAppRuleScreenState extends State<AddWhatsAppRuleScreen> {
  // ── Controllers & state ──────────────────────────────────────────────────

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _message;

  /// "time_based" | "event_based"
  late String _triggerType;

  /// "all" | "present" | "absent"
  late String _condition;

  late TimeOfDay _time;
  late List<String> _sendTo;
  late bool _isActive;

  bool _saving = false;
  String? _saveError;

  // ── Statics ──────────────────────────────────────────────────────────────

  static const _triggerOptions = <String, String>{
    'time_based': 'Time-based',
    'event_based': 'Event-based',
  };

  static const _conditionOptions = <String, String>{
    'all': 'All',
    'present': 'Present',
    'absent': 'Absent',
  };

  static const _sendToOptions = ['admin', 'warden', 'class_teacher'];

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final r = widget.existingRule;
    _name = TextEditingController(text: r?.ruleName ?? '');
    _phone = TextEditingController(text: r?.phoneNumber ?? '');
    _message = TextEditingController(text: r?.customMessage ?? '');
    _triggerType = r?.triggerType ?? 'time_based';
    _condition = r?.condition ?? 'all';
    _isActive = r?.isActive ?? true;
    _sendTo = List.of(r?.sendTo ?? ['admin']);

    // Parse send_time "HH:mm"
    if (r?.sendTime != null) {
      final parts = r!.sendTime.split(':');
      _time = (parts.length == 2)
          ? TimeOfDay(
              hour: int.tryParse(parts[0]) ?? 9,
              minute: int.tryParse(parts[1]) ?? 0,
            )
          : const TimeOfDay(hour: 9, minute: 0);
    } else {
      _time = const TimeOfDay(hour: 9, minute: 0);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  bool get _isEdit => widget.existingRule != null;

  String get _timeString =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Map<String, dynamic> _buildPayload() => {
        'rule_name': _name.text.trim(),
        'trigger_type': _triggerType,
        'condition': _condition,
        'send_to': _sendTo,
        'channels': ['whatsapp'],
        'phone_number': _phone.text.trim(),
        'custom_message': _message.text.trim(),
        'send_time': _timeString,
        'is_active': _isActive,
      };

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final ruleName = _name.text.trim();
    if (ruleName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a rule name.')),
      );
      return;
    }
    if (_phone.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number.')),
      );
      return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      final payload = _buildPayload();
      WhatsAppRule result;
      if (_isEdit) {
        result = await WhatsAppRulesApi.updateRule(
          widget.existingRule!.id,
          payload,
        );
      } else {
        result = await WhatsAppRulesApi.createRule(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'Rule updated.' : 'Rule created.'),
          ),
        );
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      setState(() => _saveError = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
              // ── Rule Name ──────────────────────────────────────────────
              AppTextField(
                label: 'Rule Name',
                hint: 'e.g. Notify warden of absentees',
                controller: _name,
              ),
              const SizedBox(height: 24),

              // ── Trigger ────────────────────────────────────────────────
              _sectionLabel('TRIGGER'),
              const SizedBox(height: 8),
              _dropdown(
                value: _triggerType,
                items: _triggerOptions,
                onChanged: (v) => setState(() => _triggerType = v),
              ),
              if (_triggerType == 'time_based') ...[
                const SizedBox(height: 12),
                _pickerRow(
                  icon: LucideIcons.clock,
                  label: 'Send Time',
                  value: _time.format(context),
                  onTap: _pickTime,
                ),
              ],
              const SizedBox(height: 24),

              // ── Condition ──────────────────────────────────────────────
              _sectionLabel('CONDITION'),
              const SizedBox(height: 8),
              _dropdown(
                value: _condition,
                items: _conditionOptions,
                onChanged: (v) => setState(() => _condition = v),
              ),
              const SizedBox(height: 24),

              // ── Action ─────────────────────────────────────────────────
              _sectionLabel('ACTION'),
              const SizedBox(height: 8),

              Text('Send to', style: AppTextStyles.caption),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in _sendToOptions)
                    _selectChip(
                      _prettyRecipient(r),
                      _sendTo.contains(r),
                      () => setState(() {
                        _sendTo.contains(r)
                            ? _sendTo.remove(r)
                            : _sendTo.add(r);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Channel is always WhatsApp — show as read-only badge
              Text('Channel', style: AppTextStyles.caption),
              const SizedBox(height: 8),
              _readOnlyChip('WhatsApp', LucideIcons.messageCircle),
              const SizedBox(height: 16),

              AppTextField(
                label: 'Phone Number',
                hint: '+91XXXXXXXXXX',
                prefixIcon: LucideIcons.phone,
                controller: _phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'Custom Message (optional)',
                hint: 'Add a note included with the alert…',
                controller: _message,
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Active toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Rule Active', style: AppTextStyles.body),
                  Switch.adaptive(
                    value: _isActive,
                    activeTrackColor: AppColors.primary,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ],
              ),

              if (_saveError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.alertCircle,
                          size: 16, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _saveError!,
                          style: AppTextStyles.caption
                              .copyWith(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              PrimaryButton(
                label: _saving
                    ? 'Saving…'
                    : (_isEdit ? 'Update Rule' : 'Save Rule'),
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(text, style: AppTextStyles.label);

  String _prettyRecipient(String raw) {
    switch (raw) {
      case 'admin':
        return 'Admin';
      case 'warden':
        return 'Warden';
      case 'class_teacher':
        return 'Class Teacher';
      default:
        return raw;
    }
  }

  Widget _dropdown({
    required String value,
    required Map<String, String> items,
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
            for (final entry in items.entries)
              DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value),
              ),
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
          const Icon(LucideIcons.chevronRight,
              size: 16, color: AppColors.textMuted),
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

  Widget _readOnlyChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.infoBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
