import 'package:flutter/material.dart';
import '../../theme/app_icons.dart';

import '../../data/mock_data.dart';
import '../../models/camera.dart';
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
  final List<CameraModel> _cameras = List.of(MockData.cameras);

  void _addCamera() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddCameraScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cameras.isEmpty) {
      return EmptyState(
        icon: LucideIcons.video,
        title: 'No cameras yet',
        subtitle: 'Add your first IP camera to start tracking attendance.',
        actionLabel: 'Add Camera',
        onAction: _addCamera,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${_cameras.length} cameras', style: AppTextStyles.caption),
            SecondaryButton(
              label: 'Add Camera',
              icon: LucideIcons.plus,
              fullWidth: false,
              onPressed: _addCamera,
            ),
          ],
        ),
        const SizedBox(height: 16),
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
        MaterialPageRoute(builder: (_) => CameraSettingsScreen(camera: cam)),
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
                const SizedBox(height: 2),
                Text(
                  cam.rtspUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
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
