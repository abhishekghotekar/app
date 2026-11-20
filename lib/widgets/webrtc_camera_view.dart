import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

/// Ultra-low latency, real-time WebRTC Live Camera Viewer.
///
/// Handshakes with the backend via:
/// `POST /face/webrtc-offer`
///
/// Flow:
/// 1. Creates an RTCPeerConnection with STUN server.
/// 2. Generates an SDP offer (RecvOnly video).
/// 3. Sends offer JSON to backend: `{"sdp": "...", "type": "offer"}`.
/// 4. Receives answer JSON from backend: `{"sdp": "...", "type": "answer"}`.
/// 5. Renders incoming live video stream with zero buffering lag!
class WebRtcCameraView extends StatefulWidget {
  const WebRtcCameraView({
    super.key,
    required this.offerUrl,
    this.headers,
    this.fit = BoxFit.contain,
    this.onConnected,
    this.onError,
  });

  final String offerUrl;
  final Map<String, String>? headers;
  final BoxFit fit;
  final VoidCallback? onConnected;
  final ValueChanged<String>? onError;

  @override
  State<WebRtcCameraView> createState() => _WebRtcCameraViewState();
}

class _WebRtcCameraViewState extends State<WebRtcCameraView> {
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;

  bool _isConnecting = true;
  bool _isConnected = false;
  String? _error;
  bool _disposed = false;
  bool _remoteDescriptionSet = false;
  bool _hasReportedError = false;

  @override
  void initState() {
    super.initState();
    _initAndConnect();
  }

  @override
  void didUpdateWidget(covariant WebRtcCameraView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offerUrl != widget.offerUrl) {
      _reconnect();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cleanup();
    super.dispose();
  }

  Future<void> _cleanup() async {
    try {
      _renderer.srcObject = null;
      await _renderer.dispose();
      await _peerConnection?.close();
      await _peerConnection?.dispose();
      _peerConnection = null;
    } catch (e) {
      debugPrint('[WebRTC] Cleanup error: $e');
    }
  }

  Future<void> _initAndConnect() async {
    try {
      _remoteDescriptionSet = false;
      _hasReportedError = false;

      if (mounted) {
        setState(() {
          _isConnecting = true;
          _isConnected = false;
          _error = null;
        });
      }

      await _renderer.initialize();
      if (_disposed) return;
      await _createOfferAndConnect();
    } catch (e) {
      _handleFailure('Initialization failed: $e');
    }
  }

  Future<void> _reconnect() async {
    if (_disposed) return;
    try {
      _renderer.srcObject = null;
      await _peerConnection?.close();
      await _peerConnection?.dispose();
      _peerConnection = null;
    } catch (_) {}
    _initAndConnect();
  }

  Future<void> _createOfferAndConnect() async {
    if (_disposed) return;

    try {
      // 1. Configure PeerConnection with public Google STUN server
      final Map<String, dynamic> rtcConfiguration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
      };

      _peerConnection = await createPeerConnection(rtcConfiguration);
      if (_disposed) return;

      // 2. Add receiver transceiver for incoming video stream (recvonly)
      await _peerConnection!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(
          direction: TransceiverDirection.RecvOnly,
        ),
      );
      if (_disposed) return;

      // 3. Listen for incoming video track from Raspberry Pi
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        debugPrint('[WebRTC] Received track: ${event.track.kind}');
        if (event.track.kind == 'video' && event.streams.isNotEmpty) {
          if (mounted && !_disposed) {
            setState(() {
              _renderer.srcObject = event.streams[0];
              _isConnected = true;
              _isConnecting = false;
              _error = null;
            });
            widget.onConnected?.call();
          }
        }
      };

      // 4. Connection State listener — only check for failure AFTER remote answer is set
      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        debugPrint('[WebRTC] Connection state: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          if (mounted && !_disposed) {
            setState(() {
              _isConnected = true;
              _isConnecting = false;
              _error = null;
            });
            widget.onConnected?.call();
          }
        } else if (_remoteDescriptionSet &&
            (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
             state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected)) {
          _handleFailure('WebRTC disconnected ($state)');
        }
      };

      // 5. Create SDP Offer
      final RTCSessionDescription offer = await _peerConnection!.createOffer({
        'offerToReceiveVideo': 1,
        'offerToReceiveAudio': 0,
      });
      if (_disposed) return;
      await _peerConnection!.setLocalDescription(offer);
      if (_disposed) return;

      // 6. Wait briefly for local ICE candidates to gather
      if (_peerConnection!.iceGatheringState !=
          RTCIceGatheringState.RTCIceGatheringStateComplete) {
        final completer = Completer<void>();
        _peerConnection!.onIceGatheringState = (state) {
          if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
            if (!completer.isCompleted) completer.complete();
          }
        };
        await completer.future.timeout(
          const Duration(milliseconds: 1500),
          onTimeout: () {},
        );
      }
      if (_disposed) return;

      final localDesc = await _peerConnection!.getLocalDescription();
      final String sdpToSend = localDesc?.sdp ?? offer.sdp ?? '';
      final String typeToSend = localDesc?.type ?? offer.type ?? 'offer';

      debugPrint('[WebRTC] Sending offer to ${widget.offerUrl}...');

      // 7. POST Offer to backend /face/webrtc-offer
      final requestHeaders = <String, String>{
        'accept': '*/*',
        'Content-Type': 'application/json',
      };
      if (widget.headers != null) {
        requestHeaders.addAll(widget.headers!);
      }

      final response = await http
          .post(
            Uri.parse(widget.offerUrl),
            headers: requestHeaders,
            body: jsonEncode({
              'sdp': sdpToSend,
              'type': typeToSend,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (_disposed) return;
      debugPrint('[WebRTC] Offer response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String? answerSdp = data['sdp'];
        final String? answerType = data['type'] ?? 'answer';

        if (answerSdp == null || answerSdp.isEmpty) {
          throw Exception('Backend returned empty answer SDP');
        }

        final answer = RTCSessionDescription(answerSdp, answerType);
        if (_disposed) return;
        await _peerConnection!.setRemoteDescription(answer);
        _remoteDescriptionSet = true;
        debugPrint('[WebRTC] Remote answer set successfully! Waiting for video stream...');
      } else {
        throw Exception(
          'Server returned ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      _handleFailure(e.toString());
    }
  }

  void _handleFailure(String errorMsg) {
    if (_disposed || !mounted || _hasReportedError) return;
    _hasReportedError = true;
    debugPrint('[WebRTC Error] $errorMsg');
    setState(() {
      _isConnecting = false;
      _isConnected = false;
      _error = errorMsg;
    });
    widget.onError?.call(errorMsg);
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnecting) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 14),
            const Text(
              'Connecting to WebRTC Live Stream…',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ultra-low latency live feed',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.warningBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.wifiOff,
                  color: AppColors.warning,
                  size: 26,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'WebRTC Stream Offline',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                _error!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _reconnect,
                icon: const Icon(LucideIcons.refreshCw, size: 14),
                label: const Text('Retry Connection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
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

    if (!_isConnected || _renderer.srcObject == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 12),
            Text(
              'Waiting for video track…',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RTCVideoView(
      _renderer,
      objectFit: widget.fit == BoxFit.cover
          ? RTCVideoViewObjectFit.RTCVideoViewObjectFitCover
          : RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
      mirror: false,
    );
  }
}
