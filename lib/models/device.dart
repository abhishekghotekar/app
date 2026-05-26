/// The paired CVAI hardware device (Raspberry Pi 5).
class Device {
  const Device({
    required this.name,
    required this.model,
    required this.firmware,
    required this.serialNumber,
    required this.ipAddress,
    required this.wifiSsid,
    required this.signalStrength, // 0..4 bars
    required this.online,
    required this.lastSync,
    required this.activeCameras,
  });

  final String name;
  final String model;
  final String firmware;
  final String serialNumber;
  final String ipAddress;
  final String wifiSsid;
  final int signalStrength;
  final bool online;
  final String lastSync;
  final int activeCameras;
}

/// A device discovered during a Bluetooth scan.
class BleDevice {
  const BleDevice({
    required this.name,
    required this.signalLabel,
    required this.rssiBars,
  });

  final String name;
  final String signalLabel; // "Strong", "Good", "Weak"
  final int rssiBars; // 1..3
}
