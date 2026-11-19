/// Central place for backend endpoints.
///
/// `platformBaseUrl` is the cloud Platform API (auth, accounts, attendance records).
/// `faceAttendanceBaseUrl` is the active device / local server ngrok or LAN URL
/// (face registration, user list, camera feed, whatsapp rules).
class ApiConfig {
  ApiConfig._();

  static const String platformBaseUrl = 'https://qa-new-platform.duckdns.org';
  static const String faceAttendanceBaseUrl =
      'https://7f0b-103-112-11-19.ngrok-free.app';

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
}
