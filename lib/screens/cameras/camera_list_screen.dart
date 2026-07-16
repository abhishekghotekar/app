import 'package:flutter/material.dart';
import '../../theme/app_icons.dart';

import '../../data/mock_data.dart';
import '../../models/camera.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/mjpeg_stream_player.dart';

class CameraListScreen extends StatefulWidget {
  const CameraListScreen({super.key});

  @override
  State<CameraListScreen> createState() => _CameraListScreenState();
}

class _CameraListScreenState extends State<CameraListScreen> with SingleTickerProviderStateMixin {
  List<CameraModel> get _cameras => MockData.cameras;

  bool _isCameraOn = true;
  bool _isSpeaking = false;
  bool _alexaEnabled = false;
  bool _speakerEnabled = true;

  late AnimationController _micAnimCtrl;

  @override
  void initState() {
    super.initState();
    _micAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _micAnimCtrl.dispose();
    super.dispose();
  }

  void _toggleCamera() {
    setState(() {
      _isCameraOn = !_isCameraOn;
      if (!_isCameraOn) {
        _isSpeaking = false;
        _micAnimCtrl.stop();
      }
    });
  }

  void _toggleSpeak() {
    if (!_isCameraOn) return;
    setState(() {
      _isSpeaking = !_isSpeaking;
      if (_isSpeaking) {
        _micAnimCtrl.repeat(reverse: true);
      } else {
        _micAnimCtrl.stop();
      }
    });
  }

  void _toggleAlexa() {
    setState(() {
      _alexaEnabled = !_alexaEnabled;
    });
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _alexaEnabled ? Icons.check_circle : Icons.info_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _alexaEnabled 
                    ? 'Alexa Smart Casting Enabled' 
                    : 'Alexa Smart Casting Disabled',
                style: const TextStyle(color: Colors.white, fontSize: 13.5),
              ),
            ),
          ],
        ),
        backgroundColor: _alexaEnabled ? const Color(0xFF00A2F4) : AppColors.textSecondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleSpeaker() {
    if (!_isCameraOn) return;
    setState(() {
      _speakerEnabled = !_speakerEnabled;
    });
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _speakerEnabled ? Icons.volume_up : Icons.volume_off,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _speakerEnabled 
                    ? 'Speaker Audio Enabled' 
                    : 'Speaker Audio Muted',
                style: const TextStyle(color: Colors.white, fontSize: 13.5),
              ),
            ),
          ],
        ),
        backgroundColor: _speakerEnabled ? AppColors.primary : AppColors.textSecondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Square Camera Frame near the top
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: AspectRatio(
                aspectRatio: 1.0, // Perfect Square!
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isCameraOn ? AppColors.primary.withValues(alpha: 0.3) : Colors.white10,
                      width: 1.5,
                    ),
                    boxShadow: [
                      if (_isCameraOn)
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Video Player / Offline Container
                        _isCameraOn
                            ? MjpegStreamPlayer(
                                url: cam.rtspUrl,
                                headers: const {'ngrok-skip-browser-warning': 'true'},
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: const Color(0xFF0D0F14),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.videocam_off,
                                      size: 64,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Camera Offline',
                                      style: AppTextStyles.bodyStrong.copyWith(color: Colors.white, fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Turn power ON to stream',
                                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),

                        // LIVE/STANDBY badge
                        Positioned(
                          top: 16,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isCameraOn) ...[
                                  _BlinkingLiveDot(),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'LIVE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10.5,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ] else
                                  const Text(
                                    'STANDBY',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10.5,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // Resolution Indicator
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.wifi, size: 12, color: Colors.white70),
                                const SizedBox(width: 6),
                                Text(
                                  '1080P',
                                  style: AppTextStyles.caption.copyWith(color: Colors.white70, fontSize: 10.5),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Audio Active Indicator Banner
                        if (_isSpeaking && _isCameraOn)
                          Positioned(
                            bottom: 16,
                            left: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.volume_up, size: 12, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    'AUDIO ACTIVE',
                                    style: AppTextStyles.caption.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 2. Control buttons card anchored at the bottom
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  border: Border.all(color: Colors.white12, width: 1.2),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 1. Power Toggle Button
                      _ControlCircleButton(
                        icon: _isCameraOn ? Icons.power_settings_new : Icons.power_settings_new_outlined,
                        label: _isCameraOn ? 'OFF' : 'ON',
                        isActive: _isCameraOn,
                        activeColor: AppColors.danger,
                        inactiveColor: Colors.white10,
                        iconColor: Colors.white,
                        onTap: _toggleCamera,
                      ),

                      // 2. Microphone Button
                      AnimatedBuilder(
                        animation: _micAnimCtrl,
                        builder: (context, child) {
                          double scale = 1.0;
                          if (_isSpeaking) {
                            scale = 1.0 + (_micAnimCtrl.value * 0.1);
                          }
                          return Transform.scale(
                            scale: scale,
                            child: _ControlCircleButton(
                              icon: _isSpeaking ? Icons.mic : Icons.mic_none,
                              label: _isSpeaking ? 'Speak' : 'Mute',
                              isActive: _isSpeaking,
                              enabled: _isCameraOn,
                              activeColor: AppColors.primary,
                              inactiveColor: Colors.white10,
                              iconColor: Colors.white,
                              onTap: _toggleSpeak,
                            ),
                          );
                        },
                      ),

                      // 3. Alexa Button
                      _ControlCircleButton(
                        icon: Icons.assistant,
                        label: 'Alexa',
                        isActive: _alexaEnabled,
                        activeColor: const Color(0xFF00A2F4),
                        inactiveColor: Colors.white10,
                        iconColor: Colors.white,
                        onTap: _toggleAlexa,
                      ),

                      // 4. Snapshot Button
                      _ControlCircleButton(
                        icon: Icons.photo_camera,
                        label: 'Snapshot',
                        isActive: false,
                        enabled: _isCameraOn,
                        activeColor: AppColors.success,
                        inactiveColor: Colors.white10,
                        iconColor: Colors.white,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Snapshot saved to gallery.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),

                      // 5. Speaker Button
                      _ControlCircleButton(
                        icon: _speakerEnabled ? Icons.volume_up : Icons.volume_off,
                        label: _speakerEnabled ? 'Speaker' : 'Mute',
                        isActive: _speakerEnabled,
                        enabled: _isCameraOn,
                        activeColor: AppColors.primary,
                        inactiveColor: Colors.white10,
                        iconColor: Colors.white,
                        onTap: _toggleSpeaker,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Blinking Live Dot widget ───────────────────────────────────────────
class _BlinkingLiveDot extends StatefulWidget {
  @override
  State<_BlinkingLiveDot> createState() => _BlinkingLiveDotState();
}

class _BlinkingLiveDotState extends State<_BlinkingLiveDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ── Control Circle Button widget ───────────────────────────────────────
class _ControlCircleButton extends StatelessWidget {
  const _ControlCircleButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.iconColor,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final Color iconColor;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bg = enabled
        ? (isActive ? activeColor : inactiveColor)
        : inactiveColor.withValues(alpha: 0.4);
    
    final finalIconColor = enabled 
        ? iconColor 
        : iconColor.withValues(alpha: 0.3);

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(100),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              boxShadow: [
                if (isActive && enabled)
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.4),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
              ],
            ),
            child: Icon(
              icon,
              size: 22,
              color: finalIconColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTextStyles.bodyStrong.copyWith(
              color: enabled ? Colors.white : AppColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
