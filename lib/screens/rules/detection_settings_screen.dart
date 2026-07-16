import 'package:flutter/material.dart';

import '../../services/face_register_api.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_app_bar.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';

class DetectionSettingsScreen extends StatefulWidget {
  const DetectionSettingsScreen({super.key});

  @override
  State<DetectionSettingsScreen> createState() =>
      _DetectionSettingsScreenState();
}

class _DetectionSettingsScreenState extends State<DetectionSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool _weaponEnabled = false;
  bool _wantedEnabled = false;
  bool _attendanceEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final config = await FaceRegisterApi.getConfig();
      if (mounted) {
        setState(() {
          _weaponEnabled = config['weapon_detection_enabled'] ?? false;
          _wantedEnabled = config['wanted_detection_enabled'] ?? false;
          _attendanceEnabled = config['attendance_enabled'] ?? true;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _saving = true);

    try {
      await FaceRegisterApi.updateConfig(
        weaponDetectionEnabled: _weaponEnabled,
        wantedDetectionEnabled: _wantedEnabled,
        attendanceEnabled: _attendanceEnabled,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.circleCheck, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                const Text('Configuration saved successfully!',
                    style: TextStyle(color: Colors.white, fontSize: 13.5)),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.circleAlert, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Failed to save config: $e',
                      style: const TextStyle(color: Colors.white, fontSize: 13.5)),
                ),
              ],
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppAppBar(title: 'Face Detection Rules', showBack: true),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _error != null
                ? _buildErrorView()
                : _buildConfigForm(),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.alertTriangle, size: 40, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(
              'Failed to load configuration',
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
            ElevatedButton.icon(
              onPressed: _loadConfig,
              icon: const Icon(LucideIcons.refreshCw, size: 14),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigForm() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              Text('DETECTION ENGINES', style: AppTextStyles.label),
              const SizedBox(height: 8),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    // Weapon Detection
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.shieldAlert,
                              size: 20, color: AppColors.textSecondary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Weapon Detection',
                                    style: AppTextStyles.bodyStrong),
                                const SizedBox(height: 2),
                                const Text('Run real-time weapon scanning algorithm',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: _weaponEnabled,
                            activeTrackColor: AppColors.primary,
                            onChanged: (v) => setState(() => _weaponEnabled = v),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    // Wanted Detection
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.circleAlert,
                              size: 20, color: AppColors.textSecondary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Wanted List Check',
                                    style: AppTextStyles.bodyStrong),
                                const SizedBox(height: 2),
                                const Text('Check detected faces against blacklists',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: _wantedEnabled,
                            activeTrackColor: AppColors.primary,
                            onChanged: (v) => setState(() => _wantedEnabled = v),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    // Attendance Enabled
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.userCheck,
                              size: 20, color: AppColors.textSecondary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Attendance Tracking',
                                    style: AppTextStyles.bodyStrong),
                                const SizedBox(height: 2),
                                const Text('Auto-mark user attendance when face is seen',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: _attendanceEnabled,
                            activeTrackColor: AppColors.primary,
                            onChanged: (v) => setState(() => _attendanceEnabled = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Save Button Footer
        Padding(
          padding: const EdgeInsets.all(20),
          child: PrimaryButton(
            label: 'Save Configuration',
            onPressed: _saving ? null : _saveConfig,
            loading: _saving,
            icon: _saving ? null : LucideIcons.check,
          ),
        ),
      ],
    );
  }
}
