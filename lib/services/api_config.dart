/// Central place for backend endpoints.
///
/// `platformBaseUrl` is the cloud Platform API (auth, accounts).
/// The on-device CVAI server (Raspberry Pi) is discovered at runtime and is
/// NOT configured here.
class ApiConfig {
  ApiConfig._();

  static const String platformBaseUrl = 'https://qa-new-platform.duckdns.org';
  static const String faceAttendanceBaseUrl = 'https://2092-59-97-150-29.ngrok-free.app';

  static const String loginPath = '/auth/api/auth/login';
}
