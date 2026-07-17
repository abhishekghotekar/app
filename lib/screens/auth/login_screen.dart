import 'package:flutter/material.dart';
import '../../theme/app_icons.dart';

import '../../services/auth_api.dart';
import '../../services/auth_storage.dart';
import '../../models/auth_session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/ghost_button.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';
import '../dashboard/home_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(text: 'rao.ghuge@gmail.com');
  final _password = TextEditingController(text: 'Raoghuge@2025');
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter your email and password.');
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await AuthApi.login(email: email, password: password);
      await AuthStorage.saveSession(result);
      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Something went wrong. Please try again.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _skipToApp() async {
    await AuthStorage.saveSession(
      LoginResult(
        accessToken: 'mock_access_token_from_skip_login',
        refreshToken: 'mock_refresh_token',
        publicToken: 'mock_public_token',
        expiresIn: 3600,
        user: const AuthUser(
          id: 'mock_user_id',
          firstName: 'Developer',
          lastName: 'User',
          email: 'dev@example.com',
          phone: '1234567890',
          status: 'active',
        ),
      ),
    );
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFFFFFF),
              const Color(0xFFF2F6FA),
              AppColors.primary.withValues(alpha: 0.05),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 40).clamp(
                      0.0,
                      double.infinity,
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        const SizedBox(height: 32),
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            LucideIcons.scanFace,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'CVAI',
                          style: AppTextStyles.headline.copyWith(fontSize: 28),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'AI Attendance, made effortless.',
                          style: AppTextStyles.caption,
                        ),
                        const SizedBox(height: 32),
                        AppTextField(
                          label: 'Email',
                          hint: 'you@school.edu',
                          prefixIcon: LucideIcons.mail,
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          label: 'Password',
                          hint: 'Enter your password',
                          prefixIcon: LucideIcons.lock,
                          controller: _password,
                          obscure: _obscure,
                          suffix: IconButton(
                            icon: Icon(
                              _obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GhostButton(
                            label: 'Forgot password?',
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        PrimaryButton(
                          label: 'Sign In',
                          loading: _loading,
                          onPressed: _signIn,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text('or', style: AppTextStyles.caption),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SecondaryButton(
                          label: 'Skip to App (Dev)',
                          icon: LucideIcons.arrowRight,
                          onPressed: _skipToApp,
                        ),
                        const Spacer(),
                        const SizedBox(height: 24),
                        Text(
                          '© 2026 Antigravity Labs',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
