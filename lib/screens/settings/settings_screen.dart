import 'package:flutter/material.dart';
import '../../theme/app_icons.dart';

import '../../data/mock_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/user_avatar.dart';
import '../auth/login_screen.dart';
import '../rules/rules_list_screen.dart';
import 'account_settings_screen.dart';
import 'device_settings_screen.dart';
import 'notification_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = MockData.currentUser;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        _label('ACCOUNT'),
        AppCard(
          padding: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _push(context, const AccountSettingsScreen()),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  UserAvatar(name: user.name, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name, style: AppTextStyles.bodyStrong),
                        const SizedBox(height: 2),
                        Text('${user.email}  ·  ${user.role}',
                            style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  const Icon(LucideIcons.chevronRight,
                      size: 18, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _label('DEVICE'),
        _group(context, [
          _Row(LucideIcons.cpu, 'Device Settings',
              onTap: () => _push(context, const DeviceSettingsScreen())),
        ]),
        const SizedBox(height: 24),
        _label('PREFERENCES'),
        _group(context, [
          _Row(LucideIcons.bell, 'Notifications',
              onTap: () =>
                  _push(context, const NotificationSettingsScreen())),
        ]),
        const SizedBox(height: 24),
        _label('RULES & ALERTS'),
        _group(context, [
          _Row(LucideIcons.zap, 'Automation Rules',
              onTap: () => _push(context, const RulesListScreen())),
        ]),
        const SizedBox(height: 24),
        AppCard(
          padding: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  const Icon(LucideIcons.logOut,
                      size: 18, color: AppColors.danger),
                  const SizedBox(width: 12),
                  Text('Log out',
                      style: AppTextStyles.bodyStrong
                          .copyWith(color: AppColors.danger)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(text, style: AppTextStyles.label),
      );

  Widget _group(BuildContext context, List<_Row> rows) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.title, {this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: AppTextStyles.body)),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(LucideIcons.chevronRight,
                  size: 16, color: AppColors.textMuted),
            ],
          ],
        ),
      ),
    );
  }
}
