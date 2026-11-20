/// Central place for backend endpoints.
///
/// `platformBaseUrl` is the cloud Platform API (auth, accounts, attendance records).
/// `faceAttendanceBaseUrl` is the active device tunnel URL
/// (face registration, user list, camera feed, whatsapp rules).
///
/// Tunnel types supported:
///   - Ngrok   : needs 'ngrok-skip-browser-warning: true' header
///   - Cloudflare Tunnel : no extra header needed, better streaming
///   - LAN     : direct IP, fastest
class ApiConfig {
  ApiConfig._();

  static const String platformBaseUrl = 'https://qa-new-platform.duckdns.org';

  /// ─── CHANGE THIS URL when switching tunnel ───────────────────────────────
  /// Ngrok example    : 'https://giblet-irk-marsupial.ngrok-free.dev'
  /// Cloudflare example: 'https://your-name.trycloudflare.com'
  static const String faceAttendanceBaseUrl =
      'https://giblet-irk-marsupial.ngrok-free.dev';

  /// Set to true if using Cloudflare Tunnel (no extra header needed).
  /// Set to false if using Ngrok (adds ngrok-skip-browser-warning header).
  static const bool isCloudflare = false;

  static const String loginPath = '/auth/api/auth/login';

  /// Returns [faceAttendanceBaseUrl] sanitized without any trailing slashes.
  static String get cleanFaceAttendanceBaseUrl {
    var url = faceAttendanceBaseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// Returns [platformBaseUrl] sanitized without any trailing slashes.
  static String get cleanPlatformBaseUrl {
    var url = platformBaseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// Camera endpoints
  static String get cameraSnapshotUrl => '$cleanFaceAttendanceBaseUrl/face/snapshot';
  static String get cameraVideoFeedUrl =>
      '$cleanFaceAttendanceBaseUrl/face/video-feed?resolution=480&height=480&fps=15';
  static String get cameraWebRtcOfferUrl =>
      '$cleanFaceAttendanceBaseUrl/face/webrtc-offer';
}
