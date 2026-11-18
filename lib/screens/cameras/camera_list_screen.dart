import 'package:flutter/material.dart';
import '../../theme/app_icons.dart';

import '../../data/mock_data.dart';
import '../../models/camera.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/mjpeg_stream_player.dart';
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
  int _selectedCameraIndex = 0;
  int _streamRefreshKey = 0;

  void _addCamera() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddCameraScreen()),
    );
  }

  void _refreshStream() {
    setState(() {
      _streamRefreshKey++;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Refreshing camera stream…'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _takeSnapshot() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(LucideIcons.camera, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Snapshot captured successfully.'),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cameras.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: EmptyState(
          icon: LucideIcons.video,
          title: 'No cameras yet',
          subtitle: 'Add a camera to monitor your space in real-time.',
          actionLabel: 'Add Camera',
          onAction: _addCamera,
        ),
      );
    }

    final selectedCam = _cameras[_selectedCameraIndex.clamp(0, _cameras.length - 1)];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Camera Switcher if multiple cameras
            if (_cameras.length > 1)
              Container(
                height: 48,
                color: const Color(0xFF161616),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _cameras.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final isSelected = idx == _selectedCameraIndex;
                    final cam = _cameras[idx];
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCameraIndex = idx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : const Color(0xFF262626),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          cam.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Main Camera Video Player
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.black,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LiveCameraViewScreen(camera: selectedCam),
                            ),
                          );
                        },
                        child: MjpegStreamPlayer(
                          key: ValueKey('${selectedCam.id}_$_streamRefreshKey'),
                          url: selectedCam.rtspUrl,
                          headers: const {'ngrok-skip-browser-warning': 'true'},
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),

                  // Top Stream Header Overlay
                  Positioned(
                    top: 14,
                    left: 14,
                    right: 14,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Live badge & Camera Name
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 1,
                                height: 10,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                selectedCam.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Action icons on top right
                        Row(
                          children: [
                            GestureDetector(
                              onTap: _refreshStream,
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                ),
                                child: const Icon(LucideIcons.refreshCw, color: Colors.white, size: 16),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => LiveCameraViewScreen(camera: selectedCam),
                                  ),
                                );
                              },
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                ),
                                child: const Icon(LucideIcons.maximize, color: Colors.white, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Bottom Location Badge Overlay
                  Positioned(
                    bottom: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.camera, color: Colors.white70, size: 13),
                          const SizedBox(width: 6),
                          Text(
                            selectedCam.location,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Control and Action Panel
            Container(
              color: const Color(0xFF141414),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _bottomAction(
                    icon: LucideIcons.camera,
                    label: 'Snapshot',
                    onTap: _takeSnapshot,
                  ),
                  _bottomAction(
                    icon: LucideIcons.maximize,
                    label: 'Fullscreen',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LiveCameraViewScreen(camera: selectedCam),
                        ),
                      );
                    },
                  ),
                  _bottomAction(
                    icon: LucideIcons.settings,
                    label: 'Settings',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CameraSettingsScreen(camera: selectedCam),
                        ),
                      );
                    },
                  ),
                  _bottomAction(
                    icon: LucideIcons.plus,
                    label: 'Add Camera',
                    onTap: _addCamera,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFBBBBBB),
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
