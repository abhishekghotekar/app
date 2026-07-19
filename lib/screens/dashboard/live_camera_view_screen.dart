import 'package:flutter/material.dart';
import '../../theme/app_icons.dart';

import '../../models/camera.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/mjpeg_stream_player.dart';
import '../../services/audio_listening_service.dart';

class LiveCameraViewScreen extends StatefulWidget {
  const LiveCameraViewScreen({super.key, required this.camera});

  final CameraModel camera;

  @override
  State<LiveCameraViewScreen> createState() => _LiveCameraViewScreenState();
}

class _LiveCameraViewScreenState extends State<LiveCameraViewScreen> {
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    AudioListeningService.isListeningNotifier.addListener(_onListeningStateChanged);
    _isListening = AudioListeningService.isListening;
  }

  void _onListeningStateChanged() {
    if (!mounted) return;
    setState(() {
      _isListening = AudioListeningService.isListening;
    });
  }

  @override
  void dispose() {
    AudioListeningService.isListeningNotifier.removeListener(_onListeningStateChanged);
    AudioListeningService.stopListening();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (!_isListening) {
      try {
        await AudioListeningService.startListening();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(LucideIcons.volume2, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Listening to camera audio.'),
                ],
              ),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(LucideIcons.alertTriangle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Failed to start audio: ${e.toString().replaceAll('Exception: ', '')}',
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.danger,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else {
      await AudioListeningService.stopListening();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(LucideIcons.volumeX, color: Colors.white),
                SizedBox(width: 8),
                Text('Audio listening disabled.'),
              ],
            ),
            backgroundColor: AppColors.textSecondary,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

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
          widget.camera.name,
          style: AppTextStyles.title.copyWith(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.black,
                    child: MjpegStreamPlayer(
                      url: widget.camera.rtspUrl,
                      headers: const {'ngrok-skip-browser-warning': 'true'},
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (_isListening)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.success.withOpacity(0.3),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.volume2,
                              color: Colors.white,
                              size: 13,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'LIVE AUDIO',
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  _stat('FPS', '${widget.camera.fps}'),
                  _stat('Resolution', widget.camera.resolution),
                  _stat('Faces', '${widget.camera.detectedFaces}'),
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
                  _action(
                    context,
                    _isListening ? LucideIcons.volume2 : LucideIcons.volumeX,
                    _isListening ? 'Mute' : 'Listen',
                    onTap: _toggleListening,
                  ),
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
          Text(
            value,
            style: AppTextStyles.statNumber.copyWith(
              color: Colors.white,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: AppTextStyles.label.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _action(BuildContext context, IconData icon, String label, {VoidCallback? onTap}) {
    final isActive = label == 'Mute';
    return InkWell(
      onTap: onTap ?? () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label — demo only')),
      ),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? AppColors.success : Colors.white,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: isActive ? AppColors.success : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
