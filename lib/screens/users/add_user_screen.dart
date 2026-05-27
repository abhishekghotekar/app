import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/face_register_api.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
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
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl     = TextEditingController();
  final _userIdCtrl   = TextEditingController(); // employee_id
  final _clientIdCtrl = TextEditingController(); // client_id
  final _emailCtrl    = TextEditingController();
  final _phoneCtrl    = TextEditingController();

  String _department = 'CSE';
  static const _departments = ['CSE', 'ECE', 'Mech', 'Faculty', 'Admin'];

  List<File> _capturedPhotos = [];
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _userIdCtrl.dispose();
    _clientIdCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ── Open face enrollment wizard ─────────────────────────────────────────────
  Future<void> _openCamera() async {
    final result = await Navigator.of(context).push<List<File>>(
      MaterialPageRoute(builder: (_) => const FaceEnrollmentScreen()),
    );
    if (result != null && result.isNotEmpty && mounted) {
      setState(() => _capturedPhotos = result);
    }
  }

  // ── Register via API ────────────────────────────────────────────────────────
  Future<void> _save() async {
    // Validate text fields
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Validate face photos
    if (_capturedPhotos.isEmpty) {
      _snack('Please capture at least one face photo.', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await FaceRegisterApi.register(
        employeeId:  _userIdCtrl.text.trim(),
        clientId:    _clientIdCtrl.text.trim(),
        fullName:    _nameCtrl.text.trim(),
        imageFiles:  _capturedPhotos,
      );

      if (!mounted) return;
      _snack('User registered successfully!', isError: false);
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.of(context).pop();
    } on FaceRegisterException catch (e) {
      if (mounted) _snack(e.message, isError: true);
    } catch (e) {
      if (mounted) _snack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? LucideIcons.circleAlert : LucideIcons.circleCheck,
              size: 18,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(msg,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5)),
            ),
          ],
        ),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final photosReady = _capturedPhotos.isNotEmpty;

    return Scaffold(
      appBar: const AppAppBar(title: 'Add User', showBack: true),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Full Name ──────────────────────────────────────────────
                AppTextField(
                  label: 'Full Name',
                  hint: 'e.g. Aarav Mehta',
                  controller: _nameCtrl,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Full name is required.'
                          : null,
                ),
                const SizedBox(height: 16),

                // ── User ID (employee_id) ──────────────────────────────────
                AppTextField(
                  label: 'User ID',
                  hint: 'e.g. EMP-0042',
                  controller: _userIdCtrl,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'User ID is required.'
                          : null,
                ),
                const SizedBox(height: 16),

                // ── Client ID ─────────────────────────────────────────────
                AppTextField(
                  label: 'Client ID',
                  hint: 'e.g. client-abc123',
                  controller: _clientIdCtrl,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Client ID is required.'
                          : null,
                ),
                const SizedBox(height: 16),

                // ── Department dropdown ────────────────────────────────────
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

                // ── Email (optional) ──────────────────────────────────────
                AppTextField(
                  label: 'Email (optional)',
                  hint: 'name@school.edu',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                // ── Mobile (optional) ─────────────────────────────────────
                AppTextField(
                  label: 'Mobile (optional)',
                  hint: '+91 ',
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 28),

                // ── Face Enrollment section label ─────────────────────────
                Row(
                  children: [
                    const Icon(LucideIcons.scanFace,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text('FACE ENROLLMENT', style: AppTextStyles.label),
                  ],
                ),
                const SizedBox(height: 10),

                // ── Capture card ──────────────────────────────────────────
                AppCard(
                  onTap: _saving ? null : _openCamera,
                  child: Row(
                    children: [
                      // Icon box
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: photosReady
                              ? AppColors.successBg
                              : AppColors.infoBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          photosReady
                              ? LucideIcons.checkCircle
                              : LucideIcons.camera,
                          size: 24,
                          color: photosReady
                              ? AppColors.success
                              : AppColors.info,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Capture Face Photos',
                                style: AppTextStyles.bodyStrong),
                            const SizedBox(height: 3),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: Text(
                                key: ValueKey(_capturedPhotos.length),
                                photosReady
                                    ? '${_capturedPhotos.length} of 5 photos captured ✓'
                                    : '0 of 5 photos captured  —  tap to open camera',
                                style: AppTextStyles.caption.copyWith(
                                  color: photosReady
                                      ? AppColors.success
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(LucideIcons.chevronRight,
                          size: 18, color: AppColors.textMuted),
                    ],
                  ),
                ),

                // ── Captured thumbnails ───────────────────────────────────
                if (photosReady) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 64,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _capturedPhotos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          _capturedPhotos[i],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => setState(() => _capturedPhotos = []),
                    child: Text(
                      '↺  Retake all photos',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.danger,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.danger,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // ── Save button ───────────────────────────────────────────
                PrimaryButton(
                  label: 'Register User',
                  onPressed: _saving ? null : _save,
                  loading: _saving,
                  icon: _saving ? null : LucideIcons.userPlus,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
