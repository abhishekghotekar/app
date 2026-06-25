import 'package:flutter/material.dart';
import '../../theme/app_icons.dart';

import '../../data/mock_data.dart';
import '../../models/camera.dart';
import '../../services/face_register_api.dart';
import '../../services/audio_stream_service.dart';
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

class _CameraListScreenState extends State<CameraListScreen>
    with SingleTickerProviderStateMixin {
  List<CameraModel> get _cameras => MockData.cameras;

  bool _isMicOn = false;
  double _buttonScale = 1.0;
  
  AnimationController? _micPulseController;
  Animation<double>? _micPulse1;
  Animation<double>? _micPulse2;
  Animation<double>? _micOpacity1;
  Animation<double>? _micOpacity2;

  void _initAnimations() {
    if (_micPulseController != null) return;
    
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _micPulseController = controller;

    // Staggered ring 1
    _micPulse1 = Tween<double>(begin: 1.0, end: 1.7).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );
    _micOpacity1 = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    // Staggered ring 2
    _micPulse2 = Tween<double>(begin: 1.0, end: 1.7).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );
    _micOpacity2 = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  bool _isManualStop = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    AudioStreamService.isStreamingNotifier.addListener(_onStreamStateChanged);
    _isMicOn = AudioStreamService.isStreaming;
    if (_isMicOn) {
      _micPulseController?.repeat();
    }
  }

  void _onStreamStateChanged() {
    if (!mounted) return;
    final active = AudioStreamService.isStreaming;
    if (active != _isMicOn) {
      setState(() {
        _isMicOn = active;
      });
      if (active) {
        _micPulseController?.repeat();
      } else {
        _micPulseController?.stop();
        _micPulseController?.reset();
        
        if (!_isManualStop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(LucideIcons.alertTriangle, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Voice transmission disconnected by server.'),
                  ),
                ],
              ),
              backgroundColor: AppColors.danger,
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    AudioStreamService.isStreamingNotifier.removeListener(_onStreamStateChanged);
    _micPulseController?.dispose();
    AudioStreamService.stopStream();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    _initAnimations();
    
    if (!_isMicOn) {
      _isManualStop = false;
      try {
        await AudioStreamService.startStream();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(LucideIcons.mic, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Voice transmission active. Speak now!'),
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
      _isManualStop = true;
      await AudioStreamService.stopStream();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(LucideIcons.micOff, color: Colors.white),
                SizedBox(width: 8),
                Text('Voice transmission disabled.'),
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

  void _addCamera() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddCameraScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    _initAnimations();
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
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LiveCameraViewScreen(camera: cam),
                  ),
                );
              },
              child: MjpegStreamPlayer(
                url: cam.rtspUrl,
                headers: const {'ngrok-skip-browser-warning': 'true'},
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Floating Mic Button overlaid in bottom center
          Positioned(
            bottom: 36,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isMicOn) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.danger.withOpacity(0.4)),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.danger.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.fiber_manual_record, color: AppColors.danger, size: 8),
                        const SizedBox(width: 8),
                        Text(
                          'TALK-BACK ACTIVE',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const AnimatedSoundwave(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                GestureDetector(
                  onTapDown: (_) => setState(() => _buttonScale = 0.88),
                  onTapUp: (_) => setState(() => _buttonScale = 1.0),
                  onTapCancel: () => setState(() => _buttonScale = 1.0),
                  onTap: _toggleMic,
                  child: AnimatedScale(
                    scale: _buttonScale,
                    duration: const Duration(milliseconds: 100),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Dual expanding ring animations
                        if (_isMicOn) ...[
                          ScaleTransition(
                            scale: _micPulse1!,
                            child: FadeTransition(
                              opacity: _micOpacity1!,
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withOpacity(0.24),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                          ScaleTransition(
                            scale: _micPulse2!,
                            child: FadeTransition(
                              opacity: _micOpacity2!,
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withOpacity(0.24),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ],
                        // Core mic button
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOut,
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isMicOn ? AppColors.danger : Colors.white.withOpacity(0.12),
                            border: Border.all(
                              color: _isMicOn ? AppColors.danger : Colors.white.withOpacity(0.25),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _isMicOn
                                    ? AppColors.danger.withOpacity(0.4)
                                    : Colors.black.withOpacity(0.25),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isMicOn ? LucideIcons.mic : LucideIcons.micOff,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedSoundwave extends StatefulWidget {
  const AnimatedSoundwave({super.key});

  @override
  State<AnimatedSoundwave> createState() => _AnimatedSoundwaveState();
}

class _AnimatedSoundwaveState extends State<AnimatedSoundwave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<double> _barHeights = [10.0, 20.0, 14.0, 24.0, 8.0];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_barHeights.length, (index) {
            final phase = (index / _barHeights.length);
            final val = Curves.easeInOut.transform(
              ((_controller.value + phase) % 1.0),
            );
            final height = 3.0 + (_barHeights[index] - 3.0) * val;
            return Container(
              width: 3.0,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1.2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(1.5),
              ),
            );
          }),
        );
      },
    );
  }
}
