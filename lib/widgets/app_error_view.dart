import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_text_styles.dart';

/// A premium, beautiful error widget that provides both:
/// 1. A minimalist inline 'Try Again' button widget.
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
    String title = 'Something Went Wrong';
    String subtitle = 'An unexpected error occurred. Please try again.';
    IconData icon = LucideIcons.circleAlert;
    Color color = AppColors.danger;
    Color bg = AppColors.dangerBg;

    final err = error.toLowerCase();
    
    // 1. Session Expiration / Unauthorized
    if (err.contains('401') || err.contains('403') || err.contains('unauthorized') || err.contains('invalid token')) {
      title = 'Session Expired';
      subtitle = 'Your session has expired or the token is invalid. Please log in again.';
      icon = LucideIcons.lock;
      color = AppColors.danger;
      bg = AppColors.dangerBg;
    } 
    // 2. Network timeout / offline
    else if (err.contains('socketexception') || err.contains('timeout') || err.contains('network') || err.contains('host lookup')) {
      title = 'Connection Timeout';
      subtitle = 'Failed to connect to the server. Please check your internet connection and try again.';
      icon = LucideIcons.wifiOff;
      color = AppColors.warning;
      bg = AppColors.warningBg;
    }

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
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 20),
            
            // Clean high-contrast title
            Text(
              title,
              style: AppTextStyles.title.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            
            // User-friendly contextual subtitle
            Text(
              subtitle,
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
    if (widget.onRetry == null) return const SizedBox.shrink();
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: ElevatedButton.icon(
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
      ),
    );
  }
}
