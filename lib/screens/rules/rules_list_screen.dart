import 'package:flutter/material.dart';
import '../../theme/app_icons.dart';

import '../../models/whatsapp_rule.dart';
import '../../services/whatsapp_rules_api.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_app_bar.dart';
import '../../widgets/app_card.dart';
import '../../widgets/secondary_button.dart';
import 'add_rule_screen.dart';

class RulesListScreen extends StatefulWidget {
  const RulesListScreen({super.key});

  @override
  State<RulesListScreen> createState() => _RulesListScreenState();
}

class _RulesListScreenState extends State<RulesListScreen> {
  List<WhatsAppRule> _rules = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  // ── Data ────────────────────────────────────────────────────────────────

  Future<void> _loadRules() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rules = await WhatsAppRulesApi.fetchRules();
      // Sort: active first, then by id descending (newest first)
      rules.sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        return b.id.compareTo(a.id);
      });
      if (mounted) setState(() => _rules = rules);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleRule(WhatsAppRule rule) async {
    final newActive = !rule.isActive;
    // Optimistically update UI
    setState(() {
      _rules = _rules
          .map((r) => r.id == rule.id ? r.copyWith(isActive: newActive) : r)
          .toList();
    });
    try {
      final updated =
          await WhatsAppRulesApi.toggleRule(rule.id, isActive: newActive);
      setState(() {
        _rules = _rules
            .map((r) => r.id == updated.id ? updated : r)
            .toList();
      });
    } catch (e) {
      // Revert on failure
      setState(() {
        _rules = _rules
            .map((r) => r.id == rule.id ? rule : r)
            .toList();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update rule: $e')),
        );
      }
    }
  }

  Future<void> _deleteRule(WhatsAppRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Rule'),
        content: Text('Delete "${rule.ruleName}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child:
                const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await WhatsAppRulesApi.deleteRule(rule.id);
      setState(() => _rules.removeWhere((r) => r.id == rule.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rule deleted.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete rule: $e')),
        );
      }
    }
  }

  Future<void> _openAddRule({WhatsAppRule? rule}) async {
    final created = await Navigator.of(context).push<WhatsAppRule>(
      MaterialPageRoute(
        builder: (_) => AddWhatsAppRuleScreen(existingRule: rule),
      ),
    );
    if (created != null) {
      _loadRules(); // Refresh from server
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppAppBar(title: 'Rules & Alerts', showBack: true),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : _buildList(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.wifiOff, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              'Could not load rules',
              style: AppTextStyles.bodyStrong,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _error!,
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SecondaryButton(
              label: 'Retry',
              icon: LucideIcons.refreshCw,
              fullWidth: false,
              onPressed: _loadRules,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_rules.length} automation rule${_rules.length == 1 ? '' : 's'}',
              style: AppTextStyles.caption,
            ),
            SecondaryButton(
              label: 'Add Rule',
              icon: LucideIcons.plus,
              fullWidth: false,
              onPressed: () => _openAddRule(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_rules.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Center(
              child: Column(
                children: [
                  const Icon(LucideIcons.bellOff,
                      size: 40, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  Text('No rules yet', style: AppTextStyles.bodyStrong),
                  const SizedBox(height: 4),
                  Text('Tap "Add Rule" to create your first automation.',
                      style: AppTextStyles.caption),
                ],
              ),
            ),
          ),
        for (final rule in _rules) ...[
          _ruleCard(rule),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _ruleCard(WhatsAppRule rule) {
    return AppCard(
      onTap: () => _openAddRule(rule: rule),
      child: Row(
        children: [
          // Icon badge
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: rule.isActive ? AppColors.infoBg : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              rule.isTimeBased ? LucideIcons.clock : LucideIcons.zap,
              size: 20,
              color: rule.isActive ? AppColors.info : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 12),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rule.ruleName, style: AppTextStyles.bodyStrong),
                const SizedBox(height: 2),
                Text(
                  rule.displayCondition,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 2),
                Text(
                  rule.displayTrigger,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                if (rule.phoneNumber.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(LucideIcons.phone,
                          size: 10, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text(
                        rule.phoneNumber,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Delete button
          IconButton(
            icon: const Icon(LucideIcons.trash2,
                size: 16, color: AppColors.textMuted),
            onPressed: () => _deleteRule(rule),
            tooltip: 'Delete',
          ),

          // Toggle switch
          Switch.adaptive(
            value: rule.isActive,
            activeTrackColor: AppColors.primary,
            onChanged: (_) => _toggleRule(rule),
          ),
        ],
      ),
    );
  }
}
