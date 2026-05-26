import 'dart:async';
import 'dart:convert' show jsonDecode, jsonEncode, utf8;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_blue_classic/flutter_blue_classic.dart' as fbc;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/scanned_device.dart';
import '../models/wifi_network.dart';
import 'cvai_ble_protocol.dart';

/// Mobile / desktop Bluetooth discovery.
///
/// Despite the file name, this scans **both** flavours of Bluetooth and
/// merges them into a single stream:
///
/// - **BLE (advertising)** via `flutter_blue_plus` — every nearby device that
///   sends out advertising packets.
/// - **Classic (BR/EDR)** via `flutter_blue_classic` — Android only, covers
///   speakers, headsets, keyboards, the Raspberry Pi when configured for
///   classic, and any other device discoverable via classic inquiry. Also
///   surfaces already-paired devices immediately.
///
/// iOS does not allow third-party apps to do classic discovery, so on iOS
/// only BLE results will appear — that is an OS limitation, not a bug.
class BleService {
  BleService._();

  // Android 11 and lower require FINE location for reliable BLE/classic scan.
  static final int _androidSdkInt = _detectAndroidSdkInt();
  static bool get _needsFineLocationPermission =>
      Platform.isAndroid && _androidSdkInt > 0 && _androidSdkInt <= 30;

  static final fbc.FlutterBlueClassic _classic = fbc.FlutterBlueClassic(
    usesFineLocation: _needsFineLocationPermission,
  );

  // Merged in-memory device table, keyed by "kind:id" so a device that
  // happens to expose both radios is shown twice (correctly — they're
  // different pairing flows).
  static final Map<String, ScannedDevice> _devices = {};
  static final StreamController<List<ScannedDevice>> _resultsController =
      StreamController<List<ScannedDevice>>.broadcast(
        onListen: _ensureWired,
      );
  static final StreamController<bool> _scanningController =
      StreamController<bool>.broadcast();

  // Native plugin handles to the devices we've discovered, kept so we can
  // actually `connect()` / `disconnect()` them after the user picks one in
  // the pair screen. Keyed by the bare MAC / remote-id string.
  static final Map<String, BluetoothDevice> _bleDeviceCache = {};

  // Pair-attempt state, broadcast to the pair screen. Keyed by `kind:id`
  // so a BLE attempt and a Classic attempt on the same MAC don't collide.
  static final Map<String, StreamController<BleConnectionState>>
      _connectionControllers = {};
  static final Map<String, StreamSubscription<BluetoothConnectionState>>
      _bleConnSubs = {};
  static final Set<String> _loggedDiscovered = <String>{};
  static const bool _logAllDiscoveredDevices = false;

  static bool _wired = false;
  static bool _bleScanning = false;
  static bool _classicScanning = false;

  /// True on Android 11 and lower, where BLE/classic discovery depends on
  /// runtime location permission + location services being enabled.
  static bool get requiresLegacyLocationPermission =>
      _needsFineLocationPermission;

  static void _log(String message) {
    final ts = DateTime.now().toIso8601String();
    debugPrint('[BLE][$ts] ${_sanitizeLogText(message, max: 400)}');
  }

  static String _deviceTag(ScannedDevice d) {
    final name = _sanitizeLogText(
      d.name.isNotEmpty ? d.name : 'Unnamed device',
      max: 80,
    );
    return '$name | ${d.kind.name.toUpperCase()} | ${d.id}';
  }

  static String _sanitizeLogText(String raw, {int max = 120}) {
    var s = raw.replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
    if (s.isEmpty) s = 'Unnamed device';
    if (s.length > max) s = '${s.substring(0, max)}...';
    return s;
  }

  static bool get _classicSupported {
    if (Platform.isAndroid) return true;
    return false;
  }

  /// Whether this device has a usable Bluetooth radio (BLE OR classic).
  static Future<bool> isSupported() async {
    final ble = await FlutterBluePlus.isSupported;
    if (ble) return true;
    if (_classicSupported) {
      try {
        return await _classic.isSupported;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Live Bluetooth on/off state. Reports `on` if either radio is on.
  ///
  /// The first emission is the current adapter state, so the UI never has to
  /// sit in `unknown` while waiting for the first FBP change event.
  static Stream<BleAdapterState> adapterState() async* {
    yield _mapAdapter(FlutterBluePlus.adapterStateNow);
    yield* FlutterBluePlus.adapterState.map(_mapAdapter);
  }

  static BleAdapterState _mapAdapter(BluetoothAdapterState s) {
    switch (s) {
      case BluetoothAdapterState.on:
        return BleAdapterState.on;
      case BluetoothAdapterState.off:
      case BluetoothAdapterState.turningOff:
        return BleAdapterState.off;
      default:
        return BleAdapterState.unknown;
    }
  }

  /// Whether [turnOn] can pop a system dialog on this platform. Only true
  /// on Android — iOS / desktop have no programmatic way to flip the radio.
  static bool get canPromptToTurnOn => Platform.isAndroid;

  /// Ask the OS to turn Bluetooth on. Android pops the system dialog;
  /// iOS / desktop have no API for this and must be done in system settings.
  static Future<void> turnOn() async {
    if (!Platform.isAndroid) {
      throw BleException(
        'Turn Bluetooth on from your system settings, then come back here.',
      );
    }
    try {
      await FlutterBluePlus.turnOn();
    } catch (e) {
      final s = e.toString().toLowerCase();
      if (s.contains('rejected')) {
        throw BleException('You declined the Bluetooth prompt.');
      }
      throw BleException('Could not turn on Bluetooth: $e');
    }
  }

  /// Live list of devices seen across BLE + Classic, deduplicated.
  static Stream<List<ScannedDevice>> scanResults() {
    _ensureWired();
    // Replay the current snapshot to any new listener.
    scheduleMicrotask(() {
      if (!_resultsController.isClosed) {
        _resultsController.add(_snapshot());
      }
    });
    return _resultsController.stream;
  }

  /// Whether *any* scan (BLE or Classic) is currently running.
  static Stream<bool> isScanning() => _scanningController.stream;

  /// Starts BLE + Classic scans together and seeds the list with paired
  /// classic devices. Restarts cleanly if either scan is already running.
  ///
  /// [cvaiOnly] is advisory — we don't pass `withServices` to the OS
  /// scanner because macOS peripherals often carry the service UUID in
  /// the scan-response packet, which Android's pre-scan filter misses.
  /// Instead we let the OS scan everything and have the UI filter on
  /// [ScannedDevice.serviceUuids] (which we populate from
  /// `advertisementData.serviceUuids` per result). Classic discovery is
  /// skipped when [cvaiOnly] is true since classic doesn't carry
  /// service UUIDs at all.
  static Future<void> startScan({bool cvaiOnly = false}) async {
    final sdkLabel = _androidSdkInt > 0 ? _androidSdkInt.toString() : 'unknown';
    _log(
      'scan:start cvaiOnly=$cvaiOnly '
      'androidSdk=$sdkLabel requiresLegacyLocation=$_needsFineLocationPermission',
    );
    _ensureWired();
    _devices.clear();
    _loggedDiscovered.clear();
    _emitResults();

    // Seed with paired classic devices (only when we're not filtering).
    if (_classicSupported && !cvaiOnly) {
      try {
        final bonded = await _classic.bondedDevices;
        if (bonded != null) {
          for (final d in bonded) {
            _ingestClassic(d, bonded: true);
          }
          _log('scan:seeded bondedClassic=${bonded.length}');
          _emitResults();
        }
      } catch (_) {
        // bondedDevices can throw if permissions are not granted yet — the
        // live scan will still pick them up.
      }
    }

    // BLE scan.
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }
    final bleScan = FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 30),
      androidUsesFineLocation: _needsFineLocationPermission,
      androidCheckLocationServices: _needsFineLocationPermission,
    );

    // Classic scan — kicked off in parallel when we're showing everything.
    // Skip in CVAI-only mode since classic doesn't carry service UUIDs.
    if (_classicSupported && !cvaiOnly) {
      try {
        _classic.stopScan();
      } catch (_) {}
      try {
        _classic.startScan();
      } catch (_) {}
    }

    try {
      await bleScan;
      _log('scan:ble start request accepted');
    } on PlatformException catch (e) {
      _log('scan:error platform=${e.code} message=${e.message}');
      throw BleException(_humanizeScanError(e));
    } catch (e) {
      _log('scan:error $e');
      throw BleException(_humanizeScanError(e));
    }
  }

  static String _humanizeScanError(Object e) {
    final msg = (e is PlatformException ? e.message : e.toString()) ?? '';
    final lower = msg.toLowerCase();
    if (lower.contains('must be turned on') ||
        lower.contains('not enabled') ||
        lower.contains('adapter is off') ||
        lower.contains('bluetooth is off')) {
      return 'Bluetooth is turned off. Turn it on to scan for devices.';
    }
    if (lower.contains('permission')) {
      return 'Bluetooth permission is missing. Allow it in Settings.';
    }
    if (lower.contains('location service') ||
        lower.contains('location is disabled')) {
      return 'Turn on Location in Android settings, then scan again.';
    }
    return 'Could not start Bluetooth scan: $msg';
  }

  static Future<void> stopScan() async {
    _log('scan:stop requested');
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }
    if (_classicSupported) {
      try {
        _classic.stopScan();
      } catch (_) {}
    }
    _log('scan:stop complete');
  }

  /// Web-only entry point — not used on mobile.
  static Future<ScannedDevice> requestDevice({String? namePrefix}) {
    throw BleException('Use the live scan on mobile, not requestDevice.');
  }

  /// Live state of an ongoing or most recent pair attempt for [device].
  ///
  /// Always returns a broadcast stream — safe to subscribe multiple times,
  /// and to subscribe before [connect] is even called.
  static Stream<BleConnectionState> connectionState(ScannedDevice device) =>
      _controllerFor(device).stream;

  /// Actually pair with [device]: open a GATT link for BLE, trigger the
  /// system pairing dialog and wait for the bond for Classic.
  ///
  /// Throws [BleException] on failure. On success completes after the radio
  /// reports `connected` (BLE) or `bonded` (Classic). The [connectionState]
  /// stream reflects the same progression for the UI to watch.
  static Future<void> connect(ScannedDevice device) async {
    _log('connect:requested ${_deviceTag(device)}');
    final ctl = _controllerFor(device);
    ctl.add(BleConnectionState.connecting);
    _log('state:connecting ${_deviceTag(device)}');

    if (device.kind == BluetoothKind.ble) {
      await _connectBle(device, ctl);
    } else {
      await _bondClassic(device, ctl);
    }
  }

  /// Drop an active connection. No-op for Classic (the OS holds the bond).
  static Future<void> disconnect(ScannedDevice device) async {
    _log('disconnect:requested ${_deviceTag(device)}');
    if (device.kind != BluetoothKind.ble) return;
    final fbpDev = _bleDeviceCache[device.id];
    if (fbpDev == null) return;
    if (!fbpDev.isConnected) return;
    try {
      await fbpDev.disconnect();
      _log('disconnect:done ${_deviceTag(device)}');
    } catch (_) {
      // Best-effort: if the radio is already gone we don't care.
      _log('disconnect:best-effort skipped ${_deviceTag(device)}');
    }
  }

  // ---- connection internals --------------------------------------------

  static StreamController<BleConnectionState> _controllerFor(
    ScannedDevice device,
  ) {
    final key = '${device.kind.name}:${device.id}';
    return _connectionControllers.putIfAbsent(
      key,
      () => StreamController<BleConnectionState>.broadcast(),
    );
  }

  static Future<void> _connectBle(
    ScannedDevice device,
    StreamController<BleConnectionState> ctl,
  ) async {
    final fbpDev = _bleDeviceCache[device.id] ??
        BluetoothDevice(remoteId: DeviceIdentifier(device.id));
    _bleDeviceCache[device.id] = fbpDev;

    final key = '${device.kind.name}:${device.id}';

    try {
      // Android's scan and connect compete for the same radio time —
      // stop the scan first so the connect has a clear path.
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
      // If a stale GATT link is still up from a previous session, drop
      // it first. Otherwise FBP's connect() is a no-op and the UI
      // appears to "connect" instantly when in fact nothing happened.
      if (fbpDev.isConnected) {
        try {
          await fbpDev.disconnect();
        } catch (_) {}
      }
      // Do the actual GATT connect. This is the *real* call and only
      // resolves when the radio link is up (or after the timeout).
      // We intentionally do NOT subscribe to `connectionState` before
      // this — that stream emits the current cached state on subscribe,
      // which would flip our UI to "connected" instantly for any
      // previously-bonded device (AirPods, etc.) without us actually
      // doing any work.
      await fbpDev.connect(
        license: License.free,
        timeout: const Duration(seconds: 20),
      );
      if (!ctl.isClosed) ctl.add(BleConnectionState.connected);
      _log('state:connected ${_deviceTag(device)}');

      // Now subscribe so a later disconnect is reflected in the UI.
      // skip(1) drops the initial "connected" replay we just observed.
      await _bleConnSubs[key]?.cancel();
      _bleConnSubs[key] = fbpDev.connectionState.skip(1).listen((s) {
        if (ctl.isClosed) return;
        if (s == BluetoothConnectionState.disconnected) {
          ctl.add(BleConnectionState.disconnected);
          _log('state:disconnected ${_deviceTag(device)}');
        }
      });
    } catch (e) {
      if (!ctl.isClosed) ctl.add(BleConnectionState.failed);
      _log('state:failed ${_deviceTag(device)} error=$e');
      throw BleException(_humanizeBleError(e));
    }
  }

  static Future<void> _bondClassic(
    ScannedDevice device,
    StreamController<BleConnectionState> ctl,
  ) async {
    if (!_classicSupported) {
      ctl.add(BleConnectionState.failed);
      _log('state:failed ${_deviceTag(device)} reason=classic_not_supported');
      throw BleException(
        'Classic Bluetooth pairing is only supported on Android.',
      );
    }
    // If the OS already has it bonded, we're done.
    if (await _isBonded(device.id)) {
      ctl.add(BleConnectionState.connected);
      _log('state:connected ${_deviceTag(device)} (already bonded)');
      return;
    }
    try {
      _log('classic:bond start ${_deviceTag(device)}');
      await _classic.bondDevice(device.id);
    } catch (e) {
      ctl.add(BleConnectionState.failed);
      _log('state:failed ${_deviceTag(device)} error=$e');
      throw BleException('Could not start pairing: $e');
    }
    final bonded = await _waitForBond(device.id, const Duration(seconds: 30));
    if (bonded) {
      ctl.add(BleConnectionState.connected);
      _log('state:connected ${_deviceTag(device)} (bonded)');
    } else {
      ctl.add(BleConnectionState.failed);
      _log('state:failed ${_deviceTag(device)} reason=bond_timeout');
      throw BleException(
        'Pairing was not completed. Confirm the prompt on the device, '
        'then try again.',
      );
    }
  }

  static Future<bool> _isBonded(String address) async {
    try {
      final list = await _classic.bondedDevices ?? const [];
      return list.any((d) => d.address.trim() == address.trim());
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _waitForBond(String address, Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await _isBonded(address)) return true;
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    return false;
  }

  // ---- CVAI provisioning (mobile) --------------------------------------

  /// Read the WiFi list the device can see and is willing to join.
  ///
  /// The device must already be connected via [connect].
  static Future<List<WifiNetwork>> listWifiNetworks(
    ScannedDevice device,
  ) async {
    final char = await _findCvaiChar(device, CvaiBle.wifiListCharUuid);
    final bytes = await char.read();
    return _decodeWifiList(bytes);
  }

  /// Write the user's chosen SSID + password to the device. The device is
  /// expected to start trying to associate immediately and stream progress
  /// on [provisioningStatus].
  static Future<void> sendWifiCredentials(
    ScannedDevice device, {
    required String ssid,
    required String password,
  }) async {
    final char = await _findCvaiChar(device, CvaiBle.wifiCredsCharUuid);
    final payload =
        utf8.encode(jsonEncode({'ssid': ssid, 'password': password}));
    try {
      await char.write(payload);
    } catch (e) {
      throw BleException('Could not send credentials: $e');
    }
  }

  /// Subscribe to status notifications from the device. Always subscribe
  /// BEFORE writing credentials so you don't miss the first event.
  ///
  /// The returned stream stays open for the life of the connection; cancel
  /// the subscription when leaving the WiFi screen.
  static Stream<ProvisionStatus> provisioningStatus(
    ScannedDevice device,
  ) async* {
    final char = await _findCvaiChar(device, CvaiBle.statusCharUuid);
    try {
      await char.setNotifyValue(true);
    } catch (e) {
      throw BleException(
        'Device refused status updates: $e',
      );
    }
    yield* char.lastValueStream
        .where((bytes) => bytes.isNotEmpty)
        .map(_decodeStatus);
  }

  static Future<BluetoothCharacteristic> _findCvaiChar(
    ScannedDevice device,
    String charUuid,
  ) async {
    if (device.kind != BluetoothKind.ble) {
      throw BleException(
        'WiFi provisioning is only available over BLE, not Classic.',
      );
    }
    final fbpDev = _bleDeviceCache[device.id] ??
        BluetoothDevice(remoteId: DeviceIdentifier(device.id));
    if (!fbpDev.isConnected) {
      throw BleException(
        'Bluetooth disconnected. Go back and pair the device again.',
      );
    }
    final services = await fbpDev.discoverServices();
    final svc = services.where(
      (s) => s.uuid.str.toLowerCase() == CvaiBle.serviceUuid.toLowerCase(),
    );
    if (svc.isEmpty) {
      throw BleException(
        'This device is not a CVAI device — its Bluetooth services do '
        'not match. Pair the right one.',
      );
    }
    final chars = svc.first.characteristics.where(
      (c) => c.uuid.str.toLowerCase() == charUuid.toLowerCase(),
    );
    if (chars.isEmpty) {
      throw BleException(
        'Device is missing a required characteristic ($charUuid). '
        'It may be running an incompatible firmware.',
      );
    }
    return chars.first;
  }

  static List<WifiNetwork> _decodeWifiList(List<int> bytes) {
    final str = utf8.decode(bytes, allowMalformed: true).trim();
    if (str.isEmpty) return const [];
    dynamic data;
    try {
      data = jsonDecode(str);
    } catch (e) {
      throw BleException('Device sent malformed WiFi data.');
    }
    if (data is! List) {
      throw BleException('Device sent unexpected WiFi data shape.');
    }
    final list = <WifiNetwork>[];
    for (final item in data) {
      if (item is Map) {
        final net = WifiNetwork.fromJson(item.cast<String, dynamic>());
        if (net.ssid.isNotEmpty) list.add(net);
      }
    }
    return list;
  }

  static ProvisionStatus _decodeStatus(List<int> bytes) {
    final str = utf8.decode(bytes, allowMalformed: true).trim();
    if (str.isEmpty) {
      return const ProvisionStatus(
        state: ProvisionState.failed,
        message: 'Empty status from device.',
      );
    }
    try {
      final data = jsonDecode(str);
      if (data is Map) {
        return ProvisionStatus.fromJson(data.cast<String, dynamic>());
      }
    } catch (_) {}
    return ProvisionStatus(
      state: ProvisionState.failed,
      message: 'Device sent unreadable status: $str',
    );
  }

  static String _humanizeBleError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('timeout')) return 'The device did not respond in time.';
    if (s.contains('cancel')) return 'The connection was canceled.';
    if (s.contains('null gatt')) {
      return 'This device does not expose a GATT server — try a different one.';
    }
    return 'Could not connect: $e';
  }

  // ---- internals --------------------------------------------------------

  static void _ensureWired() {
    if (_wired) return;
    _wired = true;

    FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final advName = r.advertisementData.advName;
        final name =
            (advName.isNotEmpty ? advName : r.device.platformName).trim();
        final id = r.device.remoteId.str;
        _bleDeviceCache[id] = r.device;
        final uuids = r.advertisementData.serviceUuids
            .map((g) => g.str.toLowerCase())
            .toList(growable: false);
        // Merge with any previously-seen UUIDs for this device — across
        // ScanResponse packets the advertisement contents can vary, so we
        // accumulate the union of what we've ever seen.
        final existing = _devices['ble:$id'];
        final mergedUuids = existing == null
            ? uuids
            : <String>{...existing.serviceUuids, ...uuids}
                .toList(growable: false);
        final uniqueKey = 'ble:$id';
        final label = _sanitizeLogText(
          name.isNotEmpty ? name : 'Unnamed device',
          max: 80,
        );
        final isCvaiCandidate =
            label.toUpperCase().startsWith('CVAI') ||
            mergedUuids.contains(CvaiBle.serviceUuid.toLowerCase());
        if (_loggedDiscovered.add(uniqueKey) &&
            (_logAllDiscoveredDevices || isCvaiCandidate)) {
          _log(
            'scan:discovered $label | BLE | $id | rssi=${r.rssi} '
            'services=${mergedUuids.length}',
          );
        }
        _devices['ble:$id'] = ScannedDevice(
          id: id,
          name: name,
          kind: BluetoothKind.ble,
          rssi: r.rssi,
          serviceUuids: mergedUuids,
        );
      }
      _emitResults();
    });
    FlutterBluePlus.isScanning.listen((on) {
      _bleScanning = on;
      _scanningController.add(_bleScanning || _classicScanning);
    });

    if (_classicSupported) {
      try {
        _classic.scanResults.listen((d) => _ingestClassic(d));
        _classic.isScanning.listen((on) {
          _classicScanning = on;
          _scanningController.add(_bleScanning || _classicScanning);
        });
      } catch (_) {
        // Plugin not registered on this platform — silently skip classic.
      }
    }
  }

  static void _ingestClassic(fbc.BluetoothDevice d, {bool bonded = false}) {
    final id = d.address.trim();
    if (id.isEmpty) return;
    final existing = _devices['classic:$id'];
    final isBonded = bonded ||
        existing?.isBonded == true ||
        d.bondState == fbc.BluetoothBondState.bonded;
    // Prefer the user-set alias when available, then the broadcast name.
    final rawName = (d.alias?.isNotEmpty ?? false) ? d.alias! : (d.name ?? '');
    final uniqueKey = 'classic:$id';
    final label = _sanitizeLogText(
      rawName.trim().isNotEmpty ? rawName.trim() : 'Unnamed device',
      max: 80,
    );
    final isCvaiCandidate = label.toUpperCase().startsWith('CVAI');
    if (_loggedDiscovered.add(uniqueKey) &&
        (_logAllDiscoveredDevices || isCvaiCandidate)) {
      _log(
        'scan:discovered $label | CLASSIC | $id | rssi=${d.rssi} '
        'bonded=$isBonded',
      );
    }
    _devices['classic:$id'] = ScannedDevice(
      id: id,
      name: rawName.trim(),
      kind: BluetoothKind.classic,
      rssi: d.rssi,
      isBonded: isBonded,
    );
    _emitResults();
  }

  static List<ScannedDevice> _snapshot() => _devices.values.toList(growable: false);

  static void _emitResults() {
    if (_resultsController.isClosed) return;
    _resultsController.add(_snapshot());
  }

  static int _detectAndroidSdkInt() {
    if (!Platform.isAndroid) return -1;
    final version = Platform.operatingSystemVersion;
    final patterns = [
      RegExp(r'API\s*(\d+)', caseSensitive: false),
      RegExp(r'SDK\s*(\d+)', caseSensitive: false),
      RegExp(r'SDK_INT\s*[:=]\s*(\d+)', caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(version);
      if (m == null) continue;
      final parsed = int.tryParse(m.group(1) ?? '');
      if (parsed != null) return parsed;
    }
    return -1;
  }
}
