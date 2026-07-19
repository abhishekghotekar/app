import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../services/auth_storage.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_text_styles.dart';

/// A premium, beautiful error widget that provides both:
/// 1. A minimalist or rich inline error details layout with a 'Try Again' button.
/// 2. A static method [show] to present error alerts in a stunning, contextual pop-up dialog.
class AppErrorView extends StatefulWidget {
  const AppErrorView({
    super.key,
    required this.error,
    this.title,
    this.onRetry,
    this.icon,
  });

  final String error;
  final String? title;
  final VoidCallback? onRetry;
  final IconData? icon;

  /// Displays a highly styled contextual pop-up alert dialog for the error.
  static void show(BuildContext context, String error, {VoidCallback? onRetry}) {
    final err = error.toLowerCase();
    
    // 1. Session Expiration / Unauthorized (Immediate logout/redirect)
    if (err.contains('401') || err.contains('403') || err.contains('unauthorized') || err.contains('invalid token')) {
      AuthStorage.clear();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      return;
    } 

    final details = AppErrorDetails.fromError(error, customTitle: null, customIcon: null);

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Styled Icon circle
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(color: details.bg, shape: BoxShape.circle),
              child: Icon(details.icon, size: 24, color: details.color),
            ),
            const SizedBox(height: 20),
            
            // Clean high-contrast title
            Text(
              details.title,
              style: AppTextStyles.title.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            
            // User-friendly contextual subtitle
            Text(
              details.subtitle,
              style: AppTextStyles.caption.copyWith(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Beautiful row actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        onRetry();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  State<AppErrorView> createState() => _AppErrorViewState();
}

class _AppErrorViewState extends State<AppErrorView> {
  @override
  Widget build(BuildContext context) {
    // Session expiration check
    final err = widget.error.toLowerCase();
    if (err.contains('401') || err.contains('403') || err.contains('unauthorized') || err.contains('invalid token')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AuthStorage.clear();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      });
      return const SizedBox.shrink();
    }

    final details = AppErrorDetails.fromError(
      widget.error,
      customTitle: widget.title,
      customIcon: widget.icon,
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Styled Icon circle
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: details.bg,
                shape: BoxShape.circle,
              ),
              child: Icon(details.icon, size: 32, color: details.color),
            ),
            const SizedBox(height: 24),
            
            // Clean high-contrast title
            Text(
              details.title,
              style: AppTextStyles.title.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            
            // User-friendly contextual subtitle
            Text(
              details.subtitle,
              style: AppTextStyles.caption.copyWith(
                fontSize: 14,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            
            // Detailed technical message (if not network error)
            if (widget.error.isNotEmpty && 
                !err.contains('socketexception') && 
                !err.contains('timeout') && 
                !err.contains('network') && 
                !err.contains('host lookup')) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  widget.error,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            
            const SizedBox(height: 32),
            
            if (widget.onRetry != null)
              ElevatedButton.icon(
                onPressed: widget.onRetry,
                icon: const Icon(LucideIcons.refreshCw, size: 15),
                label: const Text(
                  'Try Again',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: AppColors.primary.withValues(alpha: 0.25),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Helper model to centralize mapping from an error string to UI assets.
class AppErrorDetails {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bg;

  const AppErrorDetails({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bg,
  });

  factory AppErrorDetails.fromError(String error, {String? customTitle, IconData? customIcon}) {
    String title = customTitle ?? 'Something Went Wrong';
    String subtitle = 'An unexpected error occurred. Please try again.';
    IconData icon = customIcon ?? LucideIcons.circleAlert;
    Color color = AppColors.danger;
    Color bg = AppColors.dangerBg;

    final err = error.toLowerCase();

    if (err.contains('socketexception') || 
        err.contains('timeout') || 
        err.contains('network') || 
        err.contains('host lookup')) {
      title = customTitle ?? 'Connection Timeout';
      subtitle = 'Failed to connect to the server. Please check your internet connection and try again.';
      icon = customIcon ?? LucideIcons.wifiOff;
      color = AppColors.warning;
      bg = AppColors.warningBg;
    }

    return AppErrorDetails(
      title: title,
      subtitle: subtitle,
      icon: icon,
      color: color,
      bg: bg,
    );
  }
}
