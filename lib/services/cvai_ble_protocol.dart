/// CVAI BLE provisioning protocol — the GATT contract between this app and
/// the on-device CVAI server running on the Raspberry Pi 5.
///
/// **Service:** [serviceUuid]
///
/// **Characteristics:**
///
/// - [wifiListCharUuid] (READ; NOTIFY optional)
///     UTF-8 JSON array of WiFi networks the device can see, strongest
///     first:
///         [{"ssid":"Home","rssi":-56,"secured":true}, ...]
///     One read returns the full list. The phone requests MTU 512 on
///     Android; the device should keep the JSON ≤ ~480 bytes (≈ 20 of the
///     strongest networks). Web browsers typically negotiate MTU 247 — the
///     device may detect web clients and trim further if needed.
///
/// - [wifiCredsCharUuid] (WRITE WITH RESPONSE)
///     UTF-8 JSON `{"ssid":"Home","password":"..."}`. The device should
///     attempt to associate immediately after receiving this and stream
///     progress on [statusCharUuid].
///
/// - [statusCharUuid] (READ; NOTIFY)
///     UTF-8 JSON status object. The phone subscribes BEFORE writing
///     credentials so it cannot miss the result:
///         {"state":"connecting"}
///         {"state":"connected","ip":"192.168.1.42","token":"abc..."}
///         {"state":"failed","error":"wrong password"}
///     `state` is one of `connecting | connected | failed`. `ip` and
///     `token` are required for `connected`. `error` is recommended for
///     `failed` (free-form string the app shows verbatim).
class CvaiBle {
  CvaiBle._();

  static const serviceUuid = 'c0a10001-1c41-4900-ad11-c151ab711a90';
  static const wifiListCharUuid = 'c0a10002-1c41-4900-ad11-c151ab711a90';
  static const wifiCredsCharUuid = 'c0a10003-1c41-4900-ad11-c151ab711a90';
  static const statusCharUuid = 'c0a10004-1c41-4900-ad11-c151ab711a90';
}
