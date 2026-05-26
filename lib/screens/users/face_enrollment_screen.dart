import 'package:flutter/material.dart';
import '../../theme/app_icons.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class FaceEnrollmentScreen extends StatefulWidget {
  const FaceEnrollmentScreen({super.key});

  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen> {
  static const _prompts = [
    'Look straight at the camera',
    'Turn slightly left',
    'Turn slightly right',
    'Tilt your head up',
    'Tilt your head down',
  ];

  int _captured = 0;

  void _capture() {
    if (_captured >= 5) return;
    setState(() => _captured++);
    if (_captured >= 5) {
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (mounted) Navigator.of(context).pop(_captured);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _captured >= 5;
    final prompt = done
        ? 'All photos captured!'
        : _prompts[_captured];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(LucideIcons.x, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              prompt,
              style: AppTextStyles.title.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              done ? 'Wrapping up…' : 'Hold still while we capture',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
            const Spacer(),
            Container(
              width: 240,
              height: 300,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(140),
                border: Border.all(
                  color: done ? AppColors.success : Colors.white,
                  width: 3,
                ),
              ),
              child: Icon(
                done ? LucideIcons.check : LucideIcons.scanFace,
                size: 72,
                color: done ? AppColors.success : Colors.white24,
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 5; i++)
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _captured
                          ? AppColors.success
                          : Colors.white24,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: _capture,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: Container(
                  margin: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? AppColors.success : Colors.white,
                  ),
                  child: done
                      ? const Icon(LucideIcons.check,
                          color: Colors.white, size: 28)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$_captured of 5 captured',
              style: AppTextStyles.caption.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}
