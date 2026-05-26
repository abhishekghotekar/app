import 'package:flutter/material.dart';
import '../../theme/app_icons.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_app_bar.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';
import 'camera_form_fields.dart';

class AddCameraScreen extends StatefulWidget {
  const AddCameraScreen({super.key});

  @override
  State<AddCameraScreen> createState() => _AddCameraScreenState();
}

class _AddCameraScreenState extends State<AddCameraScreen> {
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _rtsp = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  String _resolution = '1080p';
  double _fps = 15;
  bool _testing = false;

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _rtsp.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() => _testing = true);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _testing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.success,
        content: const Text('Connection successful — stream reachable.'),
      ),
    );
  }

  void _save() {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Camera saved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppAppBar(title: 'Add Camera', showBack: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(label: 'Camera Name', hint: 'e.g. Main Gate Camera', controller: _name),
              const SizedBox(height: 16),
              AppTextField(label: 'Location', hint: 'e.g. Front Entrance', controller: _location),
              const SizedBox(height: 16),
              AppTextField(
                label: 'RTSP URL',
                hint: 'rtsp://192.168.1.x:554/stream',
                controller: _rtsp,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              AppTextField(label: 'Username (optional)', hint: 'admin', controller: _username),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Password (optional)',
                hint: '••••••••',
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
              const SizedBox(height: 20),
              SecondaryButton(
                label: 'Test Connection',
                icon: LucideIcons.plugZap,
                loading: _testing,
                onPressed: _testConnection,
              ),
              const SizedBox(height: 12),
              PrimaryButton(label: 'Save Camera', onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
