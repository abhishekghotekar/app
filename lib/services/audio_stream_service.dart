import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Service to handle streaming microphone audio over WebSocket.
class AudioStreamService {
  AudioStreamService._();

  static AudioRecorder? _recorder;
  static WebSocket? _webSocket;
  static StreamSubscription<Uint8List>? _audioSub;
  static StreamSubscription<dynamic>? _wsSub;
  static bool _isStopping = false;
  static int _totalBytesSent = 0;

  static const String _defaultWsUrl =
      'wss://baap-tunnel-13-201-117-192.nip.io/t/62fbc2f06d0d721c/audio/stream';

  /// Notifies listeners when streaming starts or stops.
  static final ValueNotifier<bool> isStreamingNotifier = ValueNotifier<bool>(
    false,
  );

  static bool get isStreaming => isStreamingNotifier.value;

  /// Starts capturing microphone audio and streaming it to the WebSocket.
  static Future<void> startStream({String? wsUrl}) async {
    if (isStreaming) {
      debugPrint('[AudioStream] Already streaming audio.');
      return;
    }

    final url = wsUrl ?? _defaultWsUrl;
    debugPrint('[AudioStream] Requesting microphone permission...');

    // Check and request microphone permission
    final permissionStatus = await Permission.microphone.request();
    if (!permissionStatus.isGranted) {
      throw Exception('Microphone permission is required for talk-back.');
    }

    _recorder = AudioRecorder();

    // Verify that the recorder itself has permission (double check)
    final hasRecorderPerm = await _recorder!.hasPermission();
    if (!hasRecorderPerm) {
      _recorder!.dispose();
      _recorder = null;
      throw Exception('Recorder microphone permission was denied.');
    }

    debugPrint('[AudioStream] Connecting to WebSocket: $url');
    try {
      _webSocket = await WebSocket.connect(
        url,
        headers: const {
          'ngrok-skip-browser-warning': 'true',
          'accept': '*/*',
          'user-agent': 'Mozilla/5.0 (CVAI Talk-Back Client)',
        },
      ).timeout(const Duration(seconds: 10));
      debugPrint('[AudioStream] WebSocket connected successfully.');

      // Listen for socket events to handle remote disconnects/errors
      _wsSub = _webSocket!.listen(
        (message) {
          debugPrint('[AudioStream] Received from WebSocket server: $message');
        },
        onError: (err) {
          debugPrint('[AudioStream] WebSocket error: $err');
          stopStream();
        },
        onDone: () {
          debugPrint(
            '[AudioStream] WebSocket closed by server. '
            'Code: ${_webSocket?.closeCode}, Reason: ${_webSocket?.closeReason}',
          );
          stopStream();
        },
        cancelOnError: true,
      );
    } catch (e) {
      _recorder!.dispose();
      _recorder = null;
      _webSocket = null;
      debugPrint('[AudioStream] WebSocket connection failed: $e');
      throw Exception('Failed to connect to audio streaming server: $e');
    }

    debugPrint('[AudioStream] Starting audio capture stream...');
    try {
      final audioStream = await _recorder!.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits, // 16-bit PCM raw audio
          sampleRate: 16000, // 16kHz sample rate
          numChannels: 1, // Mono channel
        ),
      );

      _totalBytesSent = 0;
      _audioSub = audioStream.listen(
        (data) {
          if (_webSocket != null && _webSocket!.readyState == WebSocket.open) {
            _webSocket!.add(data);
            _totalBytesSent += data.length;
            debugPrint('[AudioStream] Sent ${data.length} bytes to server. Total sent: $_totalBytesSent bytes');
          }
        },
        onError: (err) {
          debugPrint('[AudioStream] Error in audio stream: $err');
          stopStream();
        },
        onDone: () {
          debugPrint('[AudioStream] Audio capture stream ended.');
          stopStream();
        },
      );

      isStreamingNotifier.value = true;
    } catch (e) {
      debugPrint('[AudioStream] Failed to start stream capture: $e');
      await stopStream();
      throw Exception('Failed to start microphone streaming: $e');
    }
  }

  /// Stops streaming and cleans up the WebSocket and recorder resources.
  static Future<void> stopStream() async {
    if (_isStopping) return;
    _isStopping = true;

    debugPrint('[AudioStream] Stopping stream and cleaning up resources...');

    await _audioSub?.cancel();
    _audioSub = null;

    await _wsSub?.cancel();
    _wsSub = null;

    try {
      if (_recorder != null) {
        await _recorder!.stop();
        await _recorder!.dispose();
      }
    } catch (e) {
      debugPrint('[AudioStream] Error disposing recorder: $e');
    }
    _recorder = null;

    try {
      if (_webSocket != null) {
        await _webSocket!.close();
      }
    } catch (e) {
      debugPrint('[AudioStream] Error closing WebSocket: $e');
    }
    _webSocket = null;

    isStreamingNotifier.value = false;
    _isStopping = false;
    debugPrint('[AudioStream] Clean up complete.');
  }
}
