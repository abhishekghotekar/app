import 'package:flutter/material.dart';
import '../../theme/app_icons.dart';

import '../../data/mock_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_app_bar.dart';
import '../../widgets/app_card.dart';
import '../../widgets/ghost_button.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/status_pill.dart';
import '../provisioning/ble_scan_screen.dart';

class DeviceSettingsScreen extends StatelessWidget {
  const DeviceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = MockData.device;
    return Scaffold(
      appBar: const AppAppBar(title: 'Device Settings', showBack: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text('DEVICE INFO', style: AppTextStyles.label),
            const SizedBox(height: 8),
            AppCard(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Name', style: AppTextStyles.caption),
                      const StatusPill(
                        label: 'Online',
                        type: StatusPillType.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(d.name, style: AppTextStyles.bodyStrong),
                  ),
                  const Divider(height: 20),
                  _row('Model', d.model),
                  const Divider(height: 20),
                  _row('Firmware', d.firmware),
                  const Divider(height: 20),
                  _row('Serial number', d.serialNumber),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('NETWORK', style: AppTextStyles.label),
            const SizedBox(height: 8),
            AppCard(
              child: Column(
                children: [
                  _row('WiFi SSID', d.wifiSsid),
                  const Divider(height: 20),
                  _row('IP address', d.ipAddress),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Signal strength', style: AppTextStyles.caption),
                      Row(
                        children: [
                          for (var i = 0; i < 4; i++)
                            Container(
                              width: 5,
                              height: 8.0 + i * 4,
                              margin: const EdgeInsets.only(left: 3),
                              decoration: BoxDecoration(
                                color: i < d.signalStrength
                                    ? AppColors.success
                                    : AppColors.border,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SecondaryButton(
              label: 'Pair New Device',
              icon: LucideIcons.bluetooth,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BleScanScreen()),
              ),
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              label: 'Reboot Device',
              icon: LucideIcons.refreshCw,
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reboot command sent.')),
              ),
            ),
            const SizedBox(height: 28),
            Text('DANGER ZONE', style: AppTextStyles.label),
            const SizedBox(height: 8),
            AppCard(
              borderColor: AppColors.dangerBg,
              child: Row(
                children: [
                  const Icon(LucideIcons.unplug,
                      size: 18, color: AppColors.danger),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Unpair this device from your account.',
                      style: AppTextStyles.caption,
                    ),
                  ),
                  GhostButton(
                    label: 'Unpair Device',
                    color: AppColors.danger,
                    onPressed: () => _confirmUnpair(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmUnpair(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Unpair device?', style: AppTextStyles.title),
        content: Text(
          'You will need to run Bluetooth provisioning again to reconnect.',
          style: AppTextStyles.body,
        ),
        actions: [
          GhostButton(
            label: 'Cancel',
            color: AppColors.textSecondary,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          GhostButton(
            label: 'Unpair',
            color: AppColors.danger,
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Device unpaired.')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.caption),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppTextStyles.bodyStrong,
          ),
        ),
      ],
    );
  }
}
