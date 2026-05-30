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
import '../../widgets/mjpeg_stream_player.dart';
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

    final cam = _cameras.first;

    return Container(
      color: Colors.black,
      child: Center(
        child: MjpegStreamPlayer(
          url: cam.rtspUrl,
          headers: const {'ngrok-skip-browser-warning': 'true'},
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
