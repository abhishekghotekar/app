import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:raw_sound/raw_sound_player.dart';

/// Service to handle streaming and playing live camera audio from a WebSocket.
class AudioListeningService {
  AudioListeningService._();

  static WebSocket? _webSocket;
  static StreamSubscription<dynamic>? _wsSub;
  static RawSoundPlayer? _player;
  static bool _isStopping = false;

  static const String _defaultWsUrl =
      'wss://baap-tunnel-13-201-117-192.nip.io/t/62fbc2f06d0d721c/mic/ws';

  /// Notifies listeners when audio playback starts or stops.
  static final ValueNotifier<bool> isListeningNotifier = ValueNotifier<bool>(
    false,
  );

  static bool get isListening => isListeningNotifier.value;

  /// Starts listening to camera audio from the WebSocket.
  static Future<void> startListening({String? wsUrl}) async {
    if (isListening) {
      debugPrint('[AudioListening] Already listening to audio.');
      return;
    }

    final url = wsUrl ?? _defaultWsUrl;
    debugPrint('[AudioListening] Initializing RawSoundPlayer...');

    try {
      _player = RawSoundPlayer();
      // Initialize with 16kHz sample rate, mono channel, and 16-bit PCM.
      await _player!.initialize(
        bufferSize: 4096 * 4,
        nChannels: 1,
        sampleRate: 16000,
        pcmType: RawSoundPCMType.PCMI16,
      );
      await _player!.play();
      debugPrint('[AudioListening] RawSoundPlayer initialized and playing.');
    } catch (e) {
      debugPrint('[AudioListening] Failed to initialize RawSoundPlayer: $e');
      _player = null;
      throw Exception('Failed to initialize audio player: $e');
    }

    debugPrint('[AudioListening] Connecting to WebSocket: $url');
    try {
      _webSocket = await WebSocket.connect(
        url,
        headers: const {
          'ngrok-skip-browser-warning': 'true',
          'accept': '*/*',
          'user-agent': 'Mozilla/5.0 (CVAI Audio Listener)',
        },
      ).timeout(const Duration(seconds: 10));
      debugPrint('[AudioListening] WebSocket connected successfully.');

      // Listen for socket events to feed the audio player
      _wsSub = _webSocket!.listen(
        (message) async {
          if (message is List<int>) {
            final Uint8List data = message is Uint8List
                ? message
                : Uint8List.fromList(message);
            if (_player != null) {
              await _player!.feed(data);
            }
          }
        },
        onError: (err) {
          debugPrint('[AudioListening] WebSocket error: $err');
          stopListening();
        },
        onDone: () {
          debugPrint('[AudioListening] WebSocket closed by server.');
          stopListening();
        },
        cancelOnError: true,
      );

      isListeningNotifier.value = true;
    } catch (e) {
      debugPrint('[AudioListening] WebSocket connection failed: $e');
      await stopListening();
      throw Exception('Failed to connect to audio streaming server: $e');
    }
  }

  /// Stops streaming and cleans up the WebSocket and audio player resources.
  static Future<void> stopListening() async {
    if (_isStopping) return;
    _isStopping = true;

    debugPrint('[AudioListening] Stopping audio player and WebSocket connection...');

    await _wsSub?.cancel();
    _wsSub = null;

    try {
      if (_webSocket != null) {
        await _webSocket!.close();
      }
    } catch (e) {
      debugPrint('[AudioListening] Error closing WebSocket: $e');
    }
    _webSocket = null;

    try {
      if (_player != null) {
        await _player!.stop();
        await _player!.release();
      }
    } catch (e) {
      debugPrint('[AudioListening] Error releasing RawSoundPlayer: $e');
    }
    _player = null;

    isListeningNotifier.value = false;
    _isStopping = false;
    debugPrint('[AudioListening] Clean up complete.');
  }
}
