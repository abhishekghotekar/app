import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session.dart';

/// Persists the signed-in session (tokens + name) on the device.
///
/// Uses `shared_preferences` for now. The access token should later move to
/// `flutter_secure_storage` for production hardening.
class AuthStorage {
  AuthStorage._();

  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';
  static const _kUserName = 'user_name';
  static const _kUserEmail = 'user_email';
  static const _kUserId = 'user_id';

  static Future<void> saveSession(LoginResult result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessToken, result.accessToken);
    await prefs.setString(_kRefreshToken, result.refreshToken);
    await prefs.setString(_kUserName, result.user.fullName);
    await prefs.setString(_kUserEmail, result.user.email);
    await prefs.setString(_kUserId, result.user.id);
  }

  static Future<String?> accessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kAccessToken);
  }

  static Future<String> displayName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUserName) ?? '';
  }

  static Future<String> userEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUserEmail) ?? '';
  }

  static Future<bool> isLoggedIn() async {
    final token = await accessToken();
    return token != null && token.isNotEmpty;
  }

  /// Clears the session — call this on sign out.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kRefreshToken);
    await prefs.remove(_kUserName);
    await prefs.remove(_kUserEmail);
    await prefs.remove(_kUserId);
  }
}
