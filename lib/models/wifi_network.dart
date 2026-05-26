/// A WiFi network the paired CVAI device can see on the air.
///
/// The device sends a list of these over its BLE WiFi-list characteristic
/// during provisioning; the app presents them so the user can pick one.
class WifiNetwork {
  const WifiNetwork({
    required this.ssid,
    this.rssi,
    this.secured = true,
  });

  /// Network name. Hidden networks are excluded by the device.
  final String ssid;

  /// Signal strength in dBm as seen by the device, if reported.
  final int? rssi;

  /// True for password-protected networks (WPA / WPA2 / WPA3). Open
  /// networks set this to false so the UI can skip the password prompt.
  final bool secured;

  factory WifiNetwork.fromJson(Map<String, dynamic> json) => WifiNetwork(
        ssid: (json['ssid'] as String? ?? '').trim(),
        rssi: (json['rssi'] as num?)?.toInt(),
        secured: json['secured'] as bool? ?? true,
      );
}

/// Lifecycle of a WiFi provisioning attempt on the device.
enum ProvisionState {
  /// Device is trying to associate with the chosen SSID.
  connecting,

  /// Device is on the network and has an IP / auth token to share.
  connected,

  /// Device gave up — wrong password, network out of range, etc.
  failed,

  /// Device needs the access token to authenticate with the cloud.
  request_token,
}

/// One status update from the device's status characteristic during the
/// SSID/password handoff.
class ProvisionStatus {
  const ProvisionStatus({
    required this.state,
    this.ip,
    this.token,
    this.message,
  });

  final ProvisionState state;

  /// LAN IP the device acquired once [state] is [ProvisionState.connected].
  final String? ip;

  /// Short-lived auth token the device wants the app to use when talking to
  /// its HTTP server. The token rotates on reboot.
  final String? token;

  /// Human-readable reason, set when [state] is [ProvisionState.failed].
  final String? message;

  factory ProvisionStatus.fromJson(Map<String, dynamic> json) {
    final raw = (json['state'] as String? ?? 'failed').toLowerCase().trim();
    final state = ProvisionState.values.firstWhere(
      (s) => s.name == raw,
      orElse: () => ProvisionState.failed,
    );
    return ProvisionStatus(
      state: state,
      ip: (json['ip'] as String?)?.trim(),
      token: (json['token'] as String?)?.trim(),
      message: (json['error'] as String? ?? json['message'] as String?)?.trim(),
    );
  }
}
