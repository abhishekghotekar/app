import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_app_bar.dart';
import '../../widgets/app_card.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final Map<String, bool> _values = {
    'Push notifications': true,
    'Email alerts': true,
    'WhatsApp alerts': false,
    'Absentees': true,
    'Late arrivals': true,
    'Device offline': true,
    'Daily summary': false,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppAppBar(title: 'Notifications', showBack: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text('CHANNELS', style: AppTextStyles.label),
            const SizedBox(height: 8),
            _group([
              'Push notifications',
              'Email alerts',
              'WhatsApp alerts',
            ]),
            const SizedBox(height: 24),
            Text('EVENTS', style: AppTextStyles.label),
            const SizedBox(height: 8),
            _group([
              'Absentees',
              'Late arrivals',
              'Device offline',
              'Daily summary',
            ]),
          ],
        ),
      ),
    );
  }

  Widget _group(List<String> keys) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < keys.length; i++) ...[
            if (i > 0) const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(keys[i], style: AppTextStyles.body),
                  ),
                  Switch.adaptive(
                    value: _values[keys[i]]!,
                    activeTrackColor: AppColors.primary,
                    onChanged: (v) =>
                        setState(() => _values[keys[i]] = v),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
