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
import '../../models/api_user.dart';
import '../../services/user_list_api.dart';

class AddUserScreen extends StatefulWidget {
  const AddUserScreen({super.key});

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl     = TextEditingController();
  final _userIdCtrl   = TextEditingController(); // employee_id
  final _clientIdCtrl = TextEditingController(
      text: FaceRegisterApi.clientId);
  final _emailCtrl    = TextEditingController();
  final _phoneCtrl    = TextEditingController();

  List<File> _capturedPhotos = [];
  bool _saving = false;

  List<ApiUser> _availableUsers = [];
  bool _loadingUsers = true;
  String? _loadingError;
  ApiUser? _selectedUser;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final res = await UserListApi.fetchUsers();
      if (mounted) {
        setState(() {
          _availableUsers = res.users;
          _loadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingError = 'Failed to load users: $e';
          _loadingUsers = false;
        });
      }
    }
  }

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
    // Guard: require a user to be selected before opening camera
    if (_selectedUser == null) {
      _snack('Please select a user first before capturing photos.', isError: true);
      return;
    }
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

    // Always use the confirmed selected user's IDs — never the raw text fields
    // which can be stale, empty, or manually edited.
    final user = _selectedUser;
    if (user == null) {
      _snack('Please select a user from the dropdown first.', isError: true);
      return;
    }

    final employeeId = user.employeeId.trim();
    final clientId   = user.clientId.trim().isNotEmpty
        ? user.clientId.trim()
        : FaceRegisterApi.clientId;

    setState(() => _saving = true);
    try {
      await FaceRegisterApi.register(
        employeeId:  employeeId,
        clientId:    clientId,
        fullName:    user.fullName.trim(),
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

  // ── Info row helper ─────────────────────────────────────────────────────────
  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
                // ── User Selection ──────────────────────────────────────────
                if (_loadingUsers)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppColors.primary),
                          SizedBox(height: 12),
                          Text('Loading available users...',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                  )
                else if (_loadingError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.circleAlert, color: AppColors.danger, size: 28),
                          const SizedBox(height: 10),
                          Text(_loadingError!,
                              style: const TextStyle(color: AppColors.danger, fontSize: 13),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _loadingUsers = true;
                                _loadingError = null;
                              });
                              _fetchUsers();
                            },
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
                  )
                else ...[
                  Autocomplete<ApiUser>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (_selectedUser != null || textEditingValue.text.isEmpty) {
                        return const Iterable<ApiUser>.empty();
                      }
                      return _availableUsers.where((ApiUser option) {
                        return option.fullName
                            .toLowerCase()
                            .contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    displayStringForOption: (ApiUser option) => option.fullName,
                    onSelected: (ApiUser selection) {
                      setState(() {
                        _selectedUser = selection;
                        _nameCtrl.text = selection.fullName;
                        _userIdCtrl.text = selection.employeeId;
                        _clientIdCtrl.text = selection.clientId;
                      });
                      FocusScope.of(context).unfocus();
                    },
                    fieldViewBuilder: (
                      BuildContext context,
                      TextEditingController textEditingController,
                      FocusNode focusNode,
                      VoidCallback onFieldSubmitted,
                    ) {
                      // Pre-fill text field if user is already selected
                      if (_selectedUser != null &&
                          textEditingController.text.isEmpty) {
                        textEditingController.text = _selectedUser!.fullName;
                      }

                      return AppTextField(
                        label: 'Full Name',
                        hint: 'Type name to search...',
                        controller: textEditingController,
                        focusNode: focusNode,
                        readOnly: _selectedUser != null,
                        suffix: _selectedUser == null
                            ? null
                            : IconButton(
                                icon: const Icon(LucideIcons.x, size: 16),
                                color: AppColors.textSecondary,
                                onPressed: () {
                                  setState(() {
                                    _selectedUser = null;
                                    _userIdCtrl.clear();
                                    // Reset client id back to the default — do NOT leave it blank
                                    _clientIdCtrl.text = FaceRegisterApi.clientId;
                                    _nameCtrl.clear();
                                    textEditingController.clear();
                                    _capturedPhotos = [];
                                  });
                                  focusNode.requestFocus();
                                },
                              ),
                        onChanged: (val) {
                          _nameCtrl.text = val;
                          if (_selectedUser != null &&
                              _selectedUser!.fullName != val) {
                            setState(() {
                              _selectedUser = null;
                              _userIdCtrl.clear();
                              _clientIdCtrl.text = FaceRegisterApi.clientId;
                              _capturedPhotos = [];
                            });
                          }
                        },
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Full name is required.';
                          }
                          if (_selectedUser == null) {
                            return 'Please select a valid user from the suggestions dropdown.';
                          }
                          return null;
                        },
                      );
                    },
                    optionsViewBuilder: (
                      BuildContext context,
                      AutocompleteOnSelected<ApiUser> onSelected,
                      Iterable<ApiUser> options,
                    ) {
                      if (_selectedUser != null || options.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 6,
                          borderRadius: BorderRadius.circular(12),
                          color: AppColors.surface,
                          child: Container(
                            width: MediaQuery.of(context).size.width - 40,
                            constraints: const BoxConstraints(maxHeight: 250),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shrinkWrap: true,
                              itemCount: options.length,
                              separatorBuilder: (_, sep) => const Divider(
                                color: AppColors.border,
                                height: 1,
                              ),
                              itemBuilder: (BuildContext context, int index) {
                                final ApiUser option = options.elementAt(index);
                                return InkWell(
                                  onTap: () => onSelected(option),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        // Avatar initials
                                        Container(
                                          width: 34,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            option.initials,
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                option.fullName,
                                                style: AppTextStyles.bodyStrong,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'ID: ${option.employeeId} · ${option.department ?? "No Dept"}',
                                                style: AppTextStyles.caption.copyWith(
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Badge showing enrollment status
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: option.isRegistered
                                                ? AppColors.successBg
                                                : AppColors.warningBg,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            option.isRegistered ? 'Enrolled' : 'No Face',
                                            style: AppTextStyles.label.copyWith(
                                              color: option.isRegistered
                                                  ? AppColors.success
                                                  : AppColors.warning,
                                              fontSize: 9.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                 ],

                // ── Selected user ID info card ──────────────────────────────
                if (_selectedUser != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(LucideIcons.idCard,
                                size: 13, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              'USER DETAILS',
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.primary,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _infoRow(
                          icon: LucideIcons.hash,
                          label: 'User ID',
                          value: _selectedUser!.id.isNotEmpty
                              ? _selectedUser!.id
                              : _selectedUser!.employeeId,
                        ),
                        const SizedBox(height: 6),
                        _infoRow(
                          icon: LucideIcons.building2,
                          label: 'Client ID',
                          value: _selectedUser!.clientId,
                        ),
                        if (_selectedUser!.department != null) ...[
                          const SizedBox(height: 6),
                          _infoRow(
                            icon: LucideIcons.layoutGrid,
                            label: 'Department',
                            value: _selectedUser!.department!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
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
                      separatorBuilder: (_, sep) => const SizedBox(width: 8),
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
