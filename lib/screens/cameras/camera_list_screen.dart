import 'package:flutter/material.dart';
import '../../theme/app_icons.dart';

import '../../data/mock_data.dart';
import '../../models/camera.dart';
import '../../services/face_register_api.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/status_pill.dart';
import '../dashboard/live_camera_view_screen.dart';
import 'add_camera_screen.dart';
import 'camera_settings_screen.dart';

class CameraListScreen extends StatefulWidget {
  const CameraListScreen({super.key});

  @override
  State<CameraListScreen> createState() => _CameraListScreenState();
}

class _CameraListScreenState extends State<CameraListScreen> {
  List<CameraModel> get _cameras => MockData.cameras;

  void _addCamera() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddCameraScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cameras.isEmpty) {
      return const EmptyState(
        icon: LucideIcons.video,
        title: 'No cameras yet',
        subtitle: 'Cameras will show up here.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        for (final cam in _cameras) ...[
          _cameraCard(cam),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _cameraCard(CameraModel cam) {
    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LiveCameraViewScreen(camera: cam),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cam.online ? AppColors.infoBg : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              cam.online ? LucideIcons.video : LucideIcons.videoOff,
              size: 22,
              color: cam.online ? AppColors.info : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cam.name, style: AppTextStyles.bodyStrong),
                const SizedBox(height: 2),
                Text(cam.location, style: AppTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusPill(
                label: cam.online ? 'Online' : 'Offline',
                type: cam.online
                    ? StatusPillType.success
                    : StatusPillType.danger,
              ),
              const SizedBox(height: 8),
              if (cam.online)
                InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LiveCameraViewScreen(camera: cam),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.play,
                            size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text('Live',
                            style: AppTextStyles.label
                                .copyWith(color: AppColors.primary)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
