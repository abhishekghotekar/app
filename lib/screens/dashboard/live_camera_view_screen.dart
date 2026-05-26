import 'package:flutter/material.dart';
import '../../theme/app_icons.dart';

import '../../models/camera.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class LiveCameraViewScreen extends StatelessWidget {
  const LiveCameraViewScreen({super.key, required this.camera});

  final CameraModel camera;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          camera.name,
          style: AppTextStyles.title.copyWith(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: AppColors.surfaceAlt,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.videoOff,
                        size: 44, color: AppColors.textMuted),
                    SizedBox(height: 10),
                    Text(
                      'Live preview unavailable in demo',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  _stat('FPS', '${camera.fps}'),
                  _stat('Resolution', camera.resolution),
                  _stat('Faces', '${camera.detectedFaces}'),
                ],
              ),
            ),
            const Spacer(),
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF222222))),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _action(context, LucideIcons.camera, 'Snapshot'),
                  _action(context, LucideIcons.maximize, 'Fullscreen'),
                  _action(context, LucideIcons.settings, 'Settings'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: AppTextStyles.statNumber
                  .copyWith(color: Colors.white, fontSize: 22)),
          const SizedBox(height: 2),
          Text(label.toUpperCase(),
              style: AppTextStyles.label.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _action(BuildContext context, IconData icon, String label) {
    return InkWell(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label — demo only')),
      ),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            Icon(icon, size: 22, color: Colors.white),
            const SizedBox(height: 6),
            Text(label,
                style: AppTextStyles.caption.copyWith(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
