import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_text_styles.dart';

/// Full-screen wizard that captures up to 5 face photos.
///
/// Returns `List<File>` when done, or `null` if the user cancels.
class FaceEnrollmentScreen extends StatefulWidget {
  const FaceEnrollmentScreen({super.key});

  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen>
    with SingleTickerProviderStateMixin {
  static const _maxPhotos = 5;
  static const _prompts = [
    'Look straight at the camera',
    'Turn slightly left',
    'Turn slightly right',
    'Tilt your head up',
    'Tilt your head down',
  ];

  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isCameraPermissionDenied = false;
  final List<File> _photos = [];

  bool _capturing = false;
  String? _errorMsg; // shown inline so user can see what went wrong

  // Pulse animation for the face oval
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _initCamera();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    setState(() {
      _isCameraInitialized = false;
      _isCameraPermissionDenied = false;
      _errorMsg = null;
    });

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _errorMsg = 'No cameras found on device';
        });
        return;
      }

      CameraDescription? frontCamera;
      for (var camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          frontCamera = camera;
          break;
        }
      }

      final cameraToUse = frontCamera ?? cameras.first;

      _controller = CameraController(
        cameraToUse,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.code == 'CameraAccessDenied') {
          _isCameraPermissionDenied = true;
          _errorMsg = 'Camera permission denied. Please enable camera access in system settings.';
        } else {
          _errorMsg = 'Camera initialization failed: ${e.description}';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = 'Failed to initialize camera: $e';
      });
    }
  }

  bool get _done => _photos.length >= _maxPhotos;

  // ── Open system camera ──────────────────────────────────────────────────────
  // NOTE: We let image_picker handle permission internally.
  //       Do NOT call permission_handler before this — it causes conflicts.
  Future<void> _capture() async {
    if (_capturing || _done || _controller == null || !_isCameraInitialized) return;

    setState(() {
      _capturing = true;
      _errorMsg = null;
    });

    try {
      final XFile picked = await _controller!.takePicture();

      if (!mounted) return;

      final file = File(picked.path);
      if (!file.existsSync()) {
        setState(() =>
            _errorMsg = 'Photo file not found. Please try again.');
        return;
      }

      setState(() => _photos.add(file));

      // Auto-close after last shot with a brief success pause
      if (_photos.length >= _maxPhotos) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (mounted) Navigator.of(context).pop(_photos);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = 'Camera capture failed: $e');
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
      _errorMsg = null;
    });
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final count = _photos.length;
    final bool hasError = _errorMsg != null;
    final prompt = _done ? 'All photos captured!' : _prompts[count];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon:
                        const Icon(LucideIcons.x, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$count / $_maxPhotos',
                      style: AppTextStyles.bodyStrong
                          .copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),

            // ── Prompt ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Column(
                  key: ValueKey(count),
                  children: [
                    Text(
                      prompt,
                      style: AppTextStyles.title
                          .copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _done
                          ? 'Wrapping up…'
                          : 'Tap the shutter button to take a photo',
                      style: AppTextStyles.caption
                          .copyWith(color: Colors.white54),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Error banner ─────────────────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              child: hasError
                  ? Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.circleAlert,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMsg!,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12.5),
                            ),
                          ),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _errorMsg = null),
                            child: const Icon(LucideIcons.x,
                                color: Colors.white, size: 14),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // ── Face oval ────────────────────────────────────────────────
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, child) => Transform.scale(
                    scale: _done ? 1.0 : _pulse.value,
                    child: child,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 220,
                    height: 280,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(130),
                      border: Border.all(
                        color: _done
                            ? AppColors.success
                            : hasError
                                ? AppColors.danger
                                : Colors.white,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _done
                              ? AppColors.success.withValues(alpha: 0.4)
                              : hasError
                                  ? AppColors.danger.withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.06),
                          blurRadius: 28,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(130),
                      child: _done
                          ? Image.file(
                              _photos.last,
                              fit: BoxFit.cover,
                            )
                          : (_controller == null || !_isCameraInitialized)
                              ? (_isCameraPermissionDenied
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          LucideIcons.videoOff,
                                          size: 48,
                                          color: Colors.white54,
                                        ),
                                        const SizedBox(height: 12),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          child: Text(
                                            'Camera permission is required.',
                                            style: AppTextStyles.caption.copyWith(color: Colors.white54),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextButton(
                                          onPressed: _initCamera,
                                          child: const Text('Try Again', style: TextStyle(color: Colors.white)),
                                        ),
                                      ],
                                    )
                                  : const Center(
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation(Colors.white),
                                      ),
                                    ))
                              : FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: 220,
                                    height: 220 * _controller!.value.aspectRatio,
                                    child: CameraPreview(_controller!),
                                  ),
                                ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Thumbnail strip ──────────────────────────────────────────
            if (_photos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  height: 68,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _photos.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: 8),
                    itemBuilder: (_, i) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            _photos[i],
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => _removePhoto(i),
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: const BoxDecoration(
                                color: AppColors.danger,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.x,
                                  size: 10, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 14),

            // ── Progress pills ───────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _maxPhotos; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    width: i < count ? 26 : 10,
                    height: 10,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: i < count
                          ? AppColors.success
                          : Colors.white24,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),

            // ── Shutter button ───────────────────────────────────────────
            GestureDetector(
              onTap: _capture,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _done
                        ? AppColors.success
                        : hasError
                            ? AppColors.danger
                            : Colors.white,
                    width: 4,
                  ),
                ),
                child: Center(
                  child: _capturing
                      ? const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(
                                Colors.white),
                          ),
                        )
                      : AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _done
                                ? AppColors.success
                                : Colors.white,
                          ),
                          child: _done
                              ? const Icon(LucideIcons.check,
                                  color: Colors.white, size: 32)
                              : null,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            Text(
              _done
                  ? '✓  All done!'
                  : '$count of $_maxPhotos captured',
              style: AppTextStyles.caption
                  .copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}
