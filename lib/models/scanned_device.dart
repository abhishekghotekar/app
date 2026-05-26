/// What kind of Bluetooth radio the device speaks.
///
/// - [ble] — Bluetooth Low Energy (advertising). Works on Android, iOS, web.
/// - [classic] — Classic Bluetooth (BR/EDR), discovered via inquiry. Android
///   only; iOS does not expose third-party classic discovery.
enum BluetoothKind { ble, classic }

/// A Bluetooth device discovered during a scan / chooser selection.
class ScannedDevice {
  const ScannedDevice({
    required this.id,
    required this.name,
    required this.kind,
    this.rssi,
    this.isBonded = false,
    this.serviceUuids = const [],
  });

  /// MAC address on mobile, opaque GATT id on web.
  final String id;

  /// Empty if the device did not advertise a name. The UI is expected to fall
  /// back to [id] in that case.
  final String name;

  final BluetoothKind kind;

  /// Signal strength in dBm — set during a mobile scan, null on web or for
  /// classic devices retrieved from the bonded list.
  final int? rssi;

  /// True when the OS already has this device paired/bonded.
  final bool isBonded;

  /// GATT service UUIDs the peripheral advertised (lower-cased). Empty for
  /// classic devices and for BLE devices that didn't list any services in
  /// their advertisement. The pair flow on Web Bluetooth doesn't surface
  /// this list, so it'll also be empty there.
  final List<String> serviceUuids;
}

/// Simplified Bluetooth adapter state, shared across web and mobile.
enum BleAdapterState { on, off, unknown }

/// State of an ongoing pair attempt against a [ScannedDevice].
///
/// - [connecting] — request issued, waiting for the radio.
/// - [connected]  — BLE GATT link is up (or, for classic, OS bonding finished).
/// - [disconnected] — the link dropped after being up.
/// - [failed]    — the attempt did not succeed; see the thrown [BleException]
///                 for the human-readable reason.
enum BleConnectionState { connecting, connected, disconnected, failed }

/// Thrown for Bluetooth problems worth showing the user.
class BleException implements Exception {
  BleException(this.message);

  final String message;

  @override
  String toString() => message;
}
