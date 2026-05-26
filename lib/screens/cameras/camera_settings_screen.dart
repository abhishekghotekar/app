import 'package:flutter/material.dart';
import '../../theme/app_icons.dart';

import '../../models/camera.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_app_bar.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/ghost_button.dart';
import '../../widgets/primary_button.dart';
import 'camera_form_fields.dart';

class CameraSettingsScreen extends StatefulWidget {
  const CameraSettingsScreen({super.key, required this.camera});

  final CameraModel camera;

  @override
  State<CameraSettingsScreen> createState() => _CameraSettingsScreenState();
}

class _CameraSettingsScreenState extends State<CameraSettingsScreen> {
  late final _name = TextEditingController(text: widget.camera.name);
  late final _location = TextEditingController(text: widget.camera.location);
  late final _rtsp = TextEditingController(text: widget.camera.rtspUrl);
  late final _username =
      TextEditingController(text: widget.camera.username ?? '');
  late final _password =
      TextEditingController(text: widget.camera.password ?? '');
  late String _resolution = widget.camera.resolution;
  late double _fps = widget.camera.frameRate.toDouble();
  late bool _enabled = widget.camera.enabled;

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _rtsp.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Camera settings updated.')),
    );
  }

  void _confirmDelete() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete camera?', style: AppTextStyles.title),
        content: Text(
          'This removes "${widget.camera.name}" from the device. '
          'This cannot be undone.',
          style: AppTextStyles.body,
        ),
        actions: [
          GhostButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(ctx).pop(),
            color: AppColors.textSecondary,
          ),
          GhostButton(
            label: 'Delete',
            color: AppColors.danger,
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Camera deleted.')),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppAppBar(title: 'Camera Settings', showBack: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(label: 'Camera Name', controller: _name),
              const SizedBox(height: 16),
              AppTextField(label: 'Location', controller: _location),
              const SizedBox(height: 16),
              AppTextField(
                label: 'RTSP URL',
                controller: _rtsp,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              AppTextField(
                  label: 'Username (optional)', controller: _username),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Password (optional)',
                controller: _password,
                obscure: true,
              ),
              const SizedBox(height: 16),
              Text('Resolution', style: AppTextStyles.caption),
              const SizedBox(height: 6),
              ResolutionDropdown(
                value: _resolution,
                onChanged: (v) => setState(() => _resolution = v),
              ),
              const SizedBox(height: 16),
              FrameRateSlider(
                value: _fps,
                onChanged: (v) => setState(() => _fps = v),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_enabled ? 'Enabled' : 'Disabled',
                              style: AppTextStyles.bodyStrong),
                          const SizedBox(height: 2),
                          Text(
                            'Toggle whether this camera is actively processed.',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _enabled,
                      activeTrackColor: AppColors.primary,
                      onChanged: (v) => setState(() => _enabled = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(label: 'Save Changes', onPressed: _save),
              const SizedBox(height: 28),
              Text('DANGER ZONE', style: AppTextStyles.label),
              const SizedBox(height: 8),
              AppCard(
                borderColor: AppColors.dangerBg,
                child: Row(
                  children: [
                    const Icon(LucideIcons.trash2,
                        size: 18, color: AppColors.danger),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Delete this camera permanently.',
                        style: AppTextStyles.caption,
                      ),
                    ),
                    GhostButton(
                      label: 'Delete Camera',
                      color: AppColors.danger,
                      onPressed: _confirmDelete,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
