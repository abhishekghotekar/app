import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

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
  StreamSubscription? _subscription;
  http.Client? _client;
  bool _connecting = true;
  String? _error;

  // High-performance pre-allocated buffer
  Uint8List _buffer = Uint8List(1024 * 1024); // 1MB pre-allocated
  int _writeOffset = 0;
  int _readOffset = 0;
  int _scanOffset = 0;
  int? _pendingContentLength;
  int? _pendingBodyStartIndex;

  // Frame rate throttling variables
  Timer? _renderTimer;
  Uint8List? _latestFrameBytes;
  Uint8List? _lastRenderedFrameBytes;

  @override
  void initState() {
    super.initState();
    _startStream();
    _startRenderLoop();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _client?.close();
    _renderTimer?.cancel();
    super.dispose();
  }

  void _startRenderLoop() {
    // Decouple network packet ingestion from UI rendering.
    // Rebuilding and decoding JPEGs at a maximum of 30 FPS saves massive CPU/UI thread time.
    _renderTimer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      if (_latestFrameBytes != null &&
          _latestFrameBytes != _lastRenderedFrameBytes) {
        _lastRenderedFrameBytes = _latestFrameBytes;
        if (mounted) {
          setState(() {
            _frameBytes = _latestFrameBytes;
          });
        }
      }
    });
  }

  void _addBytes(Uint8List data) {
    if (_writeOffset + data.length > _buffer.length) {
      final activeLength = _writeOffset - _readOffset;
      if (activeLength + data.length <= _buffer.length) {
        // Compact
        _buffer.setRange(0, activeLength, _buffer, _readOffset);
        _scanOffset = _scanOffset - _readOffset;
        if (_pendingBodyStartIndex != null) {
          _pendingBodyStartIndex = _pendingBodyStartIndex! - _readOffset;
        }
        _readOffset = 0;
        _writeOffset = activeLength;
        if (_scanOffset < 0) _scanOffset = 0;
      } else {
        // Grow buffer
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

  Future<void> _startStream() async {
    try {
      final request = http.Request('GET', Uri.parse(widget.url));

      // Real-time streaming optimizations to bypass proxy (ngrok, Nginx) buffering
      request.headers['Connection'] = 'keep-alive';
      request.headers['Cache-Control'] = 'no-cache';
      request.headers['Pragma'] = 'no-cache';
      request.headers['X-Accel-Buffering'] =
          'no'; // Critical: tells ngrok/Nginx to stream immediately
      request.headers['Accept'] = 'multipart/x-mixed-replace';

      if (widget.headers != null) {
        request.headers.addAll(widget.headers!);
      }

      _client = http.Client();
      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        throw Exception('Server returned status code ${response.statusCode}');
      }

      if (mounted) {
        setState(() {
          _connecting = false;
          _error = null;
        });
      }

      _subscription = response.stream.listen(
        (data) {
          // Avoid copying data if it is already a Uint8List (standard for HttpClient streams)
          final bytes = data is Uint8List ? data : Uint8List.fromList(data);
          _addBytes(bytes);

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
                // No \r\n\r\n found or too close to end. Check for \n\n (10, 10)
                int nIndex = _buffer.indexOf(10, searchIndex);
                if (nIndex != -1 &&
                    nIndex < _writeOffset - 1 &&
                    _buffer[nIndex + 1] == 10) {
                  headerSeparatorIndex = nIndex;
                  separatorLength = 2;
                }
                break;
              }

              if (_buffer[rIndex + 1] == 10 &&
                  _buffer[rIndex + 2] == 13 &&
                  _buffer[rIndex + 3] == 10) {
                headerSeparatorIndex = rIndex;
                separatorLength = 4;
                break;
              }
              searchIndex = rIndex + 1;
            }

            if (headerSeparatorIndex != -1 && separatorLength != -1) {
              final headerBytes = _buffer.sublist(
                _readOffset,
                headerSeparatorIndex,
              );
              final headerStr = String.fromCharCodes(headerBytes);

              final match = RegExp(
                r'content-length:\s*(\d+)',
                caseSensitive: false,
              ).firstMatch(headerStr);

              if (match != null) {
                _pendingContentLength = int.parse(match.group(1)!);
                _pendingBodyStartIndex = headerSeparatorIndex + separatorLength;
                continue;
              }
            } else {
              _scanOffset = _writeOffset - 3;
              if (_scanOffset < _readOffset) {
                _scanOffset = _readOffset;
              }
            }

            if (available < 2) break;

            if (_buffer[_readOffset] == 0xFF &&
                _buffer[_readOffset + 1] == 0xD8) {
              int endIndex = -1;
              for (int i = _readOffset; i < _writeOffset - 1; i++) {
                if (_buffer[i] == 0xFF && _buffer[i + 1] == 0xD9) {
                  endIndex = i + 2;
                  break;
                }
              }

              if (endIndex == -1) {
                break;
              }

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
                  if (_buffer[_writeOffset - 1] == 0xFF) {
                    _readOffset = _writeOffset - 1;
                  } else {
                    _readOffset = _writeOffset;
                  }
                  _scanOffset = _readOffset;
                }
                break;
              }

              _readOffset = startIndex;
              _scanOffset = _readOffset;
            }
          }

          if (_readOffset > 128 * 1024) {
            final activeLength = _writeOffset - _readOffset;
            _buffer.setRange(0, activeLength, _buffer, _readOffset);

            if (_pendingBodyStartIndex != null) {
              _pendingBodyStartIndex = _pendingBodyStartIndex! - _readOffset;
            }
            _scanOffset = _scanOffset - _readOffset;
            _readOffset = 0;
            _writeOffset = activeLength;
            if (_scanOffset < 0) _scanOffset = 0;
          }
        },
        onError: (err) {
          if (mounted) {
            setState(() {
              _error = 'Stream error: $err';
            });
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _error = 'Stream closed';
            });
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = 'Failed to connect: $e';
        });
      }
    }
  }

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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.danger,
                size: 36,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppTextStyles.caption.copyWith(color: AppColors.danger),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
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
                  _startStream();
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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
