import 'package:flutter/material.dart';
import '../../theme/app_icons.dart';

import '../../models/camera.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/mjpeg_stream_player.dart';

class LiveCameraViewScreen extends StatefulWidget {
  const LiveCameraViewScreen({super.key, required this.camera});

  final CameraModel camera;

  @override
  State<LiveCameraViewScreen> createState() => _LiveCameraViewScreenState();
}

class _LiveCameraViewScreenState extends State<LiveCameraViewScreen> {
  int _refreshCounter = 0;

  void _refreshStream() {
    setState(() {
      _refreshCounter++;
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
            Text('Snapshot saved to gallery.'),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.camera.name,
              style: AppTextStyles.title.copyWith(color: Colors.white, fontSize: 16),
            ),
            Text(
              widget.camera.location,
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            tooltip: 'Refresh stream',
            onPressed: _refreshStream,
          ),
          const SizedBox(width: 8),
        ],
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
                      key: ValueKey('live_${widget.camera.id}_$_refreshCounter'),
                      url: widget.camera.rtspUrl,
                      headers: const {'ngrok-skip-browser-warning': 'true'},
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.6)),
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
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                  _action(context, LucideIcons.camera, 'Snapshot', onTap: _takeSnapshot),
                  _action(context, LucideIcons.refreshCw, 'Refresh', onTap: _refreshStream),
                  _action(context, LucideIcons.video, 'Quality', onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Stream quality: ${widget.camera.resolution} @ ${widget.camera.fps}fps')),
                    );
                  }),
                  _action(context, LucideIcons.maximize, 'Expand', onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Rotate phone to view in landscape')),
                    );
                  }),
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
    return InkWell(
      onTap: onTap ?? () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label — action completed')),
      ),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: Colors.white,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
