import 'package:shared_preferences/shared_preferences.dart';

/// Persists the paired CVAI device after BLE provisioning succeeds.
///
/// The values here are what the rest of the app uses on the *running* phase
/// — IP for the device HTTP server (mDNS will refresh it if it changes),
/// token for authenticated requests, name for display.
class DeviceStorage {
  DeviceStorage._();

  static const _kIp = 'cvai_device_ip';
  static const _kToken = 'cvai_device_token';
  static const _kName = 'cvai_device_name';
  static const _kBleId = 'cvai_device_ble_id';

  static Future<void> save({
    required String bleId,
    required String name,
    required String ip,
    required String token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBleId, bleId);
    await prefs.setString(_kName, name);
    await prefs.setString(_kIp, ip);
    await prefs.setString(_kToken, token);
  }

  static Future<({String name, String ip, String token, String bleId})?>
      read() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString(_kIp);
    final token = prefs.getString(_kToken);
    if (ip == null || token == null) return null;
    return (
      name: prefs.getString(_kName) ?? 'CVAI device',
      ip: ip,
      token: token,
      bleId: prefs.getString(_kBleId) ?? '',
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kIp);
    await prefs.remove(_kToken);
    await prefs.remove(_kName);
    await prefs.remove(_kBleId);
  }
}
