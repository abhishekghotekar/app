import 'package:flutter/material.dart';
import '../../theme/app_icons.dart';

import '../../data/mock_data.dart';
import '../../models/rule.dart';
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
  late final List<Rule> _rules = List.of(MockData.rules);
  final Set<String> _disabled = {
    for (final r in MockData.rules)
      if (!r.enabled) r.id,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppAppBar(title: 'Rules & Alerts', showBack: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_rules.length} automation rules',
                    style: AppTextStyles.caption),
                SecondaryButton(
                  label: 'Add Rule',
                  icon: LucideIcons.plus,
                  fullWidth: false,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AddRuleScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (final rule in _rules) ...[
              _ruleCard(rule),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _ruleCard(Rule rule) {
    final enabled = !_disabled.contains(rule.id);
    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AddRuleScreen(rule: rule)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: enabled ? AppColors.infoBg : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              rule.type == 'Time-based'
                  ? LucideIcons.clock
                  : LucideIcons.zap,
              size: 20,
              color: enabled ? AppColors.info : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rule.name, style: AppTextStyles.bodyStrong),
                const SizedBox(height: 2),
                Text(rule.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption),
                const SizedBox(height: 2),
                Text(rule.schedule,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    )),
              ],
            ),
          ),
          Switch.adaptive(
            value: enabled,
            activeTrackColor: AppColors.primary,
            onChanged: (v) => setState(() {
              if (v) {
                _disabled.remove(rule.id);
              } else {
                _disabled.add(rule.id);
              }
            }),
          ),
        ],
      ),
    );
  }
}
