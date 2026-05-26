import 'package:flutter/material.dart';
import '../../theme/app_icons.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/status_pill.dart';
import '../dashboard/home_screen.dart';

class ProvisioningSuccessScreen extends StatelessWidget {
  const ProvisioningSuccessScreen({
    super.key,
    required this.deviceName,
    required this.ip,
    required this.ssid,
  });

  /// Name the device advertised over BLE (e.g. `CVAI-mac-b2cb`).
  final String deviceName;

  /// LAN IP the device reported after joining WiFi.
  final String ip;

  /// SSID the device joined.
  final String ssid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  color: AppColors.successBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.checkCircle2,
                    size: 64, color: AppColors.success),
              ),
              const SizedBox(height: 24),
              Text('Device is online!', style: AppTextStyles.headline),
              const SizedBox(height: 8),
              Text(
                'Your CVAI device is now connected and ready to use.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 28),
              AppCard(
                child: Column(
                  children: [
                    _row('Device', deviceName),
                    const Divider(height: 20),
                    _row('IP address', ip),
                    const Divider(height: 20),
                    _row('WiFi', ssid),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Status', style: AppTextStyles.caption),
                        const StatusPill(
                          label: 'Online',
                          type: StatusPillType.success,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Go to Dashboard',
                icon: LucideIcons.layoutDashboard,
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.caption),
        Text(value, style: AppTextStyles.bodyStrong),
      ],
    );
  }
}
