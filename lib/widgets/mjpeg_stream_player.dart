import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_icons.dart';

/// High-performance Live Camera Feed player.
///
/// Automatically supports:
/// 1. Zero-Lag Snapshot polling (`/face/snapshot`) — recommended for 100% real-time,
///    zero-buffer live video over Ngrok, Cloudflare, or LAN.
/// 2. MJPEG multipart stream (`/face/video-feed`) — with intelligent buffer draining
///    that skips stale frames so the player stays live.
/// 3. Automatic fallback between modes if one endpoint returns 404.
class MjpegStreamPlayer extends StatefulWidget {
  const MjpegStreamPlayer({
    super.key,
    required this.url,
    this.headers,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  final String url;
  final Map<String, String>? headers;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  State<MjpegStreamPlayer> createState() => _MjpegStreamPlayerState();
}

class _MjpegStreamPlayerState extends State<MjpegStreamPlayer> {
  Uint8List? _frameBytes;
  bool _connecting = true;
  String? _error;
  bool _disposed = false;

  // HTTP Client
  http.Client? _client;

  // Snapshot mode variables
  bool _isSnapshotMode = false;
  bool _fetchingSnapshot = false;
  Timer? _snapshotTimer;

  // MJPEG Stream mode variables
  StreamSubscription? _subscription;
  Uint8List _buffer = Uint8List(1024 * 1024);
  int _writeOffset = 0;
  int _readOffset = 0;
  int _scanOffset = 0;
  int? _pendingContentLength;
  int? _pendingBodyStartIndex;
  Timer? _renderTimer;
  Uint8List? _latestFrameBytes;
  Uint8List? _lastRenderedFrameBytes;

  @override
  void initState() {
    super.initState();
    _startPlayer();
  }

  @override
  void didUpdateWidget(covariant MjpegStreamPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _stopAll();
      _startPlayer();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stopAll();
    super.dispose();
  }

  void _stopAll() {
    _snapshotTimer?.cancel();
    _snapshotTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _renderTimer?.cancel();
    _renderTimer = null;
    _client?.close();
    _client = null;
    _fetchingSnapshot = false;
  }

  void _startPlayer() {
    _stopAll();
    _client = http.Client();
    _connecting = true;
    _error = null;

    final urlLower = widget.url.toLowerCase();
    if (urlLower.contains('/snapshot')) {
      _isSnapshotMode = true;
      _fetchNextSnapshot();
    } else {
      _isSnapshotMode = false;
      _startMjpegStream();
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Mode 1: Zero-Lag Snapshot Polling Engine (/face/snapshot)
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _fetchNextSnapshot() async {
    if (_disposed || !mounted) return;
    if (_fetchingSnapshot) return;
    _fetchingSnapshot = true;

    try {
      final sep = widget.url.contains('?') ? '&' : '?';
      final uri = Uri.parse('${widget.url}${sep}t=${DateTime.now().millisecondsSinceEpoch}');

      final headers = <String, String>{
        'Connection': 'keep-alive',
        'Cache-Control': 'no-cache, no-store',
        'Pragma': 'no-cache',
      };
      if (widget.headers != null) {
        headers.addAll(widget.headers!);
      }

      final response = await _client!.get(uri, headers: headers).timeout(
        const Duration(seconds: 4),
      );

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        if (mounted && !_disposed) {
          setState(() {
            _frameBytes = response.bodyBytes;
            _connecting = false;
            _error = null;
          });
        }
      } else if (response.statusCode == 404) {
        // Fallback to MJPEG if snapshot is not supported on backend
        debugPrint('[Camera] /face/snapshot returned 404. Falling back to /face/video-feed...');
        _fallbackToMjpeg();
        return;
      } else if (_frameBytes == null) {
        if (mounted && !_disposed) {
          setState(() {
            _connecting = false;
            _error = 'Camera server returned ${response.statusCode}';
          });
        }
      }
    } catch (e) {
      if (_frameBytes == null && mounted && !_disposed) {
        setState(() {
          _connecting = false;
          _error = e.toString();
        });
      }
    } finally {
      _fetchingSnapshot = false;
      if (mounted && !_disposed && _isSnapshotMode) {
        // ~18-20 FPS smooth playback with zero buffer lag
        _snapshotTimer = Timer(const Duration(milliseconds: 50), _fetchNextSnapshot);
      }
    }
  }

  void _fallbackToMjpeg() {
    _stopAll();
    _client = http.Client();
    _isSnapshotMode = false;

    // Replace /snapshot with /video-feed
    String fallbackUrl = widget.url.replaceAll('/snapshot', '/video-feed');
    if (!fallbackUrl.contains('resolution=')) {
      final sep = fallbackUrl.contains('?') ? '&' : '?';
      fallbackUrl = '$fallbackUrl${sep}resolution=480&height=480&fps=15';
    }
    _startMjpegStreamWithUrl(fallbackUrl);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Mode 2: MJPEG Multipart Stream Engine (/face/video-feed)
  // ──────────────────────────────────────────────────────────────────────────

  void _startMjpegStream() {
    _startMjpegStreamWithUrl(widget.url);
  }

  void _startMjpegStreamWithUrl(String streamUrl) {
    _renderTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      if (_latestFrameBytes != null && _latestFrameBytes != _lastRenderedFrameBytes) {
        _lastRenderedFrameBytes = _latestFrameBytes;
        if (mounted && !_disposed) {
          setState(() {
            _frameBytes = _latestFrameBytes;
            _connecting = false;
            _error = null;
          });
        }
      }
    });

    _connectMjpegStream(streamUrl);
  }

  Future<void> _connectMjpegStream(String streamUrl) async {
    try {
      final request = http.Request('GET', Uri.parse(streamUrl));
      request.headers['Connection'] = 'keep-alive';
      request.headers['Cache-Control'] = 'no-cache';
      request.headers['Pragma'] = 'no-cache';
      request.headers['X-Accel-Buffering'] = 'no';
      request.headers['Accept'] = 'multipart/x-mixed-replace';

      if (widget.headers != null) {
        request.headers.addAll(widget.headers!);
      }

      final response = await _client!.send(request);
      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      if (mounted && !_disposed) {
        setState(() {
          _connecting = false;
          _error = null;
        });
      }

      _subscription = response.stream.listen(
        (data) {
          final bytes = data is Uint8List ? data : Uint8List.fromList(data);
          _addBytes(bytes);

          // Drain frames from buffer — ALWAYS keeps the latest frame
          while (true) {
            final available = _writeOffset - _readOffset;
            if (available <= 0) break;

            if (_pendingContentLength != null) {
              final bodyStartIndex = _pendingBodyStartIndex!;
              final contentLength = _pendingContentLength!;

              if (_writeOffset >= bodyStartIndex + contentLength) {
                final frame = _buffer.sublist(
                  bodyStartIndex,
                  bodyStartIndex + contentLength,
                );

                _readOffset = bodyStartIndex + contentLength;
                _scanOffset = _readOffset;
                _pendingContentLength = null;
                _pendingBodyStartIndex = null;

                _latestFrameBytes = frame;
                continue;
              } else {
                break;
              }
            }

            int headerSeparatorIndex = -1;
            int separatorLength = -1;

            if (_scanOffset < _readOffset) {
              _scanOffset = _readOffset;
            }

            int searchIndex = _scanOffset;
            while (searchIndex < _writeOffset - 1) {
              int rIndex = _buffer.indexOf(13, searchIndex);
              if (rIndex == -1 || rIndex > _writeOffset - 4) {
                int nIndex = _buffer.indexOf(10, searchIndex);
                if (nIndex != -1 && nIndex < _writeOffset - 1 && _buffer[nIndex + 1] == 10) {
                  headerSeparatorIndex = nIndex;
                  separatorLength = 2;
                }
                break;
              }

              if (_buffer[rIndex + 1] == 10 && _buffer[rIndex + 2] == 13 && _buffer[rIndex + 3] == 10) {
                headerSeparatorIndex = rIndex;
                separatorLength = 4;
                break;
              }
              searchIndex = rIndex + 1;
            }

            if (headerSeparatorIndex != -1 && separatorLength != -1) {
              final headerBytes = _buffer.sublist(_readOffset, headerSeparatorIndex);
              final headerStr = String.fromCharCodes(headerBytes);
              final match = RegExp(r'content-length:\s*(\d+)', caseSensitive: false).firstMatch(headerStr);

              if (match != null) {
                _pendingContentLength = int.parse(match.group(1)!);
                _pendingBodyStartIndex = headerSeparatorIndex + separatorLength;
                continue;
              }
            } else {
              _scanOffset = _writeOffset - 3;
              if (_scanOffset < _readOffset) _scanOffset = _readOffset;
            }

            if (available < 2) break;

            // JPEG boundary fallback
            if (_buffer[_readOffset] == 0xFF && _buffer[_readOffset + 1] == 0xD8) {
              int endIndex = -1;
              for (int i = _readOffset; i < _writeOffset - 1; i++) {
                if (_buffer[i] == 0xFF && _buffer[i + 1] == 0xD9) {
                  endIndex = i + 2;
                  break;
                }
              }
              if (endIndex == -1) break;

              final frame = _buffer.sublist(_readOffset, endIndex);
              _readOffset = endIndex;
              _scanOffset = _readOffset;
              _latestFrameBytes = frame;
            } else {
              int startIndex = -1;
              for (int i = _readOffset; i < _writeOffset - 1; i++) {
                if (_buffer[i] == 0xFF && _buffer[i + 1] == 0xD8) {
                  startIndex = i;
                  break;
                }
              }
              if (startIndex == -1) {
                if (available > 100000) {
                  _readOffset = (_buffer[_writeOffset - 1] == 0xFF) ? _writeOffset - 1 : _writeOffset;
                  _scanOffset = _readOffset;
                }
                break;
              }
              _readOffset = startIndex;
              _scanOffset = _readOffset;
            }
          }

          // Compact buffer periodically
          if (_readOffset > 128 * 1024) {
            final activeLength = _writeOffset - _readOffset;
            _buffer.setRange(0, activeLength, _buffer, _readOffset);
            _scanOffset = _scanOffset - _readOffset;
            if (_pendingBodyStartIndex != null) {
              _pendingBodyStartIndex = _pendingBodyStartIndex! - _readOffset;
            }
            _readOffset = 0;
            _writeOffset = activeLength;
            if (_scanOffset < 0) _scanOffset = 0;
          }
        },
        onError: (e) {
          if (mounted && !_disposed) {
            setState(() {
              _connecting = false;
              _error = 'Connection lost: $e';
            });
          }
        },
        onDone: () {
          if (mounted && !_disposed && _frameBytes == null) {
            setState(() {
              _connecting = false;
              _error = 'Stream closed by server';
            });
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (mounted && !_disposed) {
        setState(() {
          _connecting = false;
          _error = 'Failed to connect: $e';
        });
      }
    }
  }

  void _addBytes(Uint8List data) {
    if (_writeOffset + data.length > _buffer.length) {
      final activeLength = _writeOffset - _readOffset;
      if (activeLength + data.length <= _buffer.length) {
        _buffer.setRange(0, activeLength, _buffer, _readOffset);
        _scanOffset = _scanOffset - _readOffset;
        if (_pendingBodyStartIndex != null) {
          _pendingBodyStartIndex = _pendingBodyStartIndex! - _readOffset;
        }
        _readOffset = 0;
        _writeOffset = activeLength;
        if (_scanOffset < 0) _scanOffset = 0;
      } else {
        int newSize = _buffer.length * 2;
        while (_writeOffset + data.length > newSize) {
          newSize *= 2;
        }
        final newBuffer = Uint8List(newSize);
        newBuffer.setRange(0, activeLength, _buffer, _readOffset);
        _buffer = newBuffer;
        _scanOffset = _scanOffset - _readOffset;
        if (_pendingBodyStartIndex != null) {
          _pendingBodyStartIndex = _pendingBodyStartIndex! - _readOffset;
        }
        _readOffset = 0;
        _writeOffset = activeLength;
        if (_scanOffset < 0) _scanOffset = 0;
      }
    }
    _buffer.setRange(_writeOffset, _writeOffset + data.length, data);
    _writeOffset += data.length;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // UI Builder
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_connecting) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 12),
            Text(
              'Connecting to Raspberry Pi Camera…',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      final err = _error!.toLowerCase();
      final isNetwork = err.contains('socketexception') ||
          err.contains('timeout') ||
          err.contains('network') ||
          err.contains('host lookup') ||
          err.contains('failed to fetch');

      final String title = isNetwork ? 'Camera Feed Offline' : 'Connection Failed';
      final String subtitle = isNetwork
          ? 'Failed to connect to the camera server. Please check the network configuration and try again.'
          : _error!;
      final IconData icon = isNetwork ? LucideIcons.wifiOff : LucideIcons.circleAlert;
      final Color iconColor = isNetwork ? AppColors.warning : AppColors.danger;
      final Color iconBg = isNetwork ? AppColors.warningBg : AppColors.dangerBg;

      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 28, color: iconColor),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: AppTextStyles.bodyStrong.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 12.5,
                  height: 1.4,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _connecting = true;
                    _error = null;
                    _frameBytes = null;
                    _latestFrameBytes = null;
                    _lastRenderedFrameBytes = null;
                    _writeOffset = 0;
                    _readOffset = 0;
                    _scanOffset = 0;
                    _pendingContentLength = null;
                    _pendingBodyStartIndex = null;
                  });
                  _startPlayer();
                },
                icon: const Icon(LucideIcons.refreshCw, size: 14),
                label: const Text(
                  'Retry',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_frameBytes == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 12),
            Text(
              'Waiting for video frame…',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Image.memory(
      _frameBytes!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true,
    );
  }
}
