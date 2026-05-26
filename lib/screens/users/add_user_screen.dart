import 'package:flutter/material.dart';
import '../../theme/app_icons.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_app_bar.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import 'face_enrollment_screen.dart';

class AddUserScreen extends StatefulWidget {
  const AddUserScreen({super.key});

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _name = TextEditingController();
  final _id = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  String _department = 'CSE';
  int _photosCaptured = 0;

  static const _departments = ['CSE', 'ECE', 'Mech', 'Faculty'];

  @override
  void dispose() {
    _name.dispose();
    _id.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _enrollFace() async {
    final result = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => const FaceEnrollmentScreen()),
    );
    if (result != null && mounted) {
      setState(() => _photosCaptured = result);
    }
  }

  void _save() {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User saved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppAppBar(title: 'Add User', showBack: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(label: 'Full Name', hint: 'e.g. Aarav Mehta', controller: _name),
              const SizedBox(height: 16),
              AppTextField(label: 'ID / Roll Number', hint: 'e.g. CSE-2201', controller: _id),
              const SizedBox(height: 16),
              Text('Department', style: AppTextStyles.caption),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _department,
                    isExpanded: true,
                    icon: const Icon(LucideIcons.chevronDown,
                        size: 18, color: AppColors.textSecondary),
                    style: AppTextStyles.body,
                    borderRadius: BorderRadius.circular(8),
                    items: [
                      for (final d in _departments)
                        DropdownMenuItem(value: d, child: Text(d)),
                    ],
                    onChanged: (v) =>
                        setState(() => _department = v ?? _department),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Email (optional)',
                hint: 'name@school.edu',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Phone (optional)',
                hint: '+91 ',
                controller: _phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),
              Text('FACE ENROLLMENT', style: AppTextStyles.label),
              const SizedBox(height: 8),
              AppCard(
                onTap: _enrollFace,
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.infoBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.camera,
                          size: 22, color: AppColors.info),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Capture Face Photos',
                              style: AppTextStyles.bodyStrong),
                          const SizedBox(height: 2),
                          Text('$_photosCaptured of 5 photos captured',
                              style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                    const Icon(LucideIcons.chevronRight,
                        size: 18, color: AppColors.textMuted),
                  ],
                ),
              ),
              if (_photosCaptured > 0) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (var i = 0; i < _photosCaptured; i++)
                      Container(
                        width: 48,
                        height: 48,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(LucideIcons.user,
                            size: 22, color: AppColors.textMuted),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              PrimaryButton(label: 'Save User', onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
