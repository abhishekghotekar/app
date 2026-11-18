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

  // Cache of known device names from bonded/paired OS records or previous scans
  // so a device connected in Android settings never loses its name.
  static final Map<String, String> _bondedNameCache = {};

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

    // Immediately seed all bonded and connected devices from the phone's OS
    // so paired devices (like Raspberry Pi) appear right away with their full names.
    await _seedBondedDevices();

    // Pure BLE (Bluetooth Low Energy / GATT) scan via FlutterBluePlus ONLY
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }
    final bleScan = FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 30),
      androidUsesFineLocation: _needsFineLocationPermission,
      androidCheckLocationServices: _needsFineLocationPermission,
    );

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

  /// Seeds paired/bonded and system-connected Bluetooth devices from Android / OS.
  /// This ensures that if the Raspberry Pi was paired via Android Bluetooth Settings,
  /// its name and MAC are immediately present and can be connected via BLE GATT.
  static Future<void> _seedBondedDevices() async {
    _log('scan:seeding bonded and connected devices from OS...');

    // 1. Ingest FlutterBluePlus bonded devices
    try {
      final bleBonded = await FlutterBluePlus.bondedDevices;
      _log('scan:seeded bondedBle=${bleBonded.length}');
      for (final d in bleBonded) {
        final id = d.remoteId.str.trim();
        if (id.isEmpty) continue;
        _bleDeviceCache[id] = d;
        final name = (d.platformName.isNotEmpty ? d.platformName : d.advName).trim();
        if (name.isNotEmpty) _bondedNameCache[id] = name;
        _ingestBondedDevice(id: id, name: name);
      }
    } catch (e) {
      _log('scan:seed BLE bonded error: $e');
    }

    // 2. Ingest FlutterBluePlus system-connected devices
    try {
      final systemDevs = await FlutterBluePlus.systemDevices([]);
      _log('scan:seeded systemBle=${systemDevs.length}');
      for (final d in systemDevs) {
        final id = d.remoteId.str.trim();
        if (id.isEmpty) continue;
        _bleDeviceCache[id] = d;
        final name = (d.platformName.isNotEmpty ? d.platformName : d.advName).trim();
        if (name.isNotEmpty) _bondedNameCache[id] = name;
        _ingestBondedDevice(id: id, name: name);
      }
    } catch (e) {
      _log('scan:seed system devices error: $e');
    }

    // 3. Ingest Classic bonded devices from Android OS
    if (_classicSupported) {
      try {
        final classicBonded = await _classic.bondedDevices;
        if (classicBonded != null) {
          _log('scan:seeded bondedClassic=${classicBonded.length}');
          for (final d in classicBonded) {
            final id = d.address.trim();
            if (id.isEmpty) continue;
            final rawName = (d.alias?.isNotEmpty ?? false) ? d.alias! : (d.name ?? '');
            final name = rawName.trim();
            if (name.isNotEmpty) _bondedNameCache[id] = name;
            _bleDeviceCache[id] = BluetoothDevice(remoteId: DeviceIdentifier(id));
            _ingestBondedDevice(id: id, name: name);
          }
        }
      } catch (e) {
        _log('scan:seed classic bonded error: $e');
      }
    }

    _emitResults();
  }

  static void _ingestBondedDevice({required String id, required String name}) {
    if (id.isEmpty) return;
    final cachedName = _bondedNameCache[id] ?? '';
    final resolvedName = name.isNotEmpty ? name : cachedName;
    final existing = _devices['ble:$id'];
    final finalName = resolvedName.isNotEmpty
        ? resolvedName
        : (existing?.name.isNotEmpty ?? false)
            ? existing!.name
            : '';

    final label = _sanitizeLogText(
      finalName.isNotEmpty ? finalName : 'Unnamed device',
      max: 80,
    );
    _log('scan:bonded device ingested "$label" ($id)');

    _devices['ble:$id'] = ScannedDevice(
      id: id,
      name: finalName,
      kind: BluetoothKind.ble,
      rssi: existing?.rssi ?? -45,
      isBonded: true,
      serviceUuids: existing?.serviceUuids ?? const [],
    );
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

    // Pure BLE (Bluetooth Low Energy / GATT) connection
    await _connectBle(device, ctl);
  }

  /// Drop an active connection. No-op for Classic (the OS holds the bond).
  static Future<void> disconnect(ScannedDevice device) async {
    _log('disconnect:requested ${_deviceTag(device)}');
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

      if (Platform.isAndroid) {
        try {
          _log('requesting MTU 512 for Android...');
          await fbpDev.requestMtu(512, timeout: 5);
          _log('MTU requested successfully');
        } catch (e) {
          _log('requestMtu failed: $e');
        }
      }

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
      final msg = e.toString();
      if (msg.contains('android-code: 147') ||
          msg.contains('GATT_CONNECTION_TIMEOUT') ||
          msg.contains('Timed out after 20s')) {
        throw BleException(
          'BLE GATT connection timed out (Code 147). '
          'Please ensure the BLE provisioning service (ble_provisioning.py) is running on the Raspberry Pi.',
        );
      }
      if (msg.contains('android-code: 133') || msg.contains('ANDROID_SPECIFIC_ERROR')) {
        throw BleException(
          'Could not reach the device over BLE (Error 133). '
          'Please move closer and tap Try again.',
        );
      }
      throw BleException('Could not connect: $e');
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
    _log('Raw WiFi list bytes read: $bytes');
    final decodedStr = utf8.decode(bytes, allowMalformed: true).trim();
    _log('Raw WiFi list string: "$decodedStr"');
    return _decodeWifiList(bytes);
  }

  /// Write the user's chosen SSID + password to the device. The device is
  /// expected to start trying to associate immediately and stream progress
  /// on [provisioningStatus].
  static Future<void> sendWifiCredentials(
    ScannedDevice device, {
    required String ssid,
    required String password,
    String? token,
    String? clientId,
  }) async {
    final char = await _findCvaiChar(device, CvaiBle.wifiCredsCharUuid);

    String? cleanToken;
    if (token != null && token.trim().isNotEmpty) {
      cleanToken = token.trim();
      if (cleanToken.startsWith('Bearer ')) {
        cleanToken = cleanToken.substring(7).trim();
      }
    }

    final jsonMap = <String, dynamic>{
      'ssid': ssid.trim(),
      'password': password.trim(),
      if (cleanToken != null && cleanToken.isNotEmpty) 'token': cleanToken,
      if (clientId != null && clientId.isNotEmpty) 'client_id': clientId.trim(),
    };
    final jsonStr = jsonEncode(jsonMap);
    _log('Sending WiFi credentials & login Bearer token JSON (${jsonStr.length} B): $jsonStr');
    final payload = utf8.encode(jsonStr);
    try {
      await char.write(payload, allowLongWrite: true);
      _log('WiFi credentials & login token successfully sent over BLE.');
    } catch (e) {
      throw BleException('Could not send credentials: $e');
    }
  }

  /// Write only the user's access token to the device when requested.
  ///
  /// The BLE characteristic does NOT support long writes (max: 512 bytes).
  /// We send a single compact JSON `{"token":"..."}` and, if the token
  /// exceeds 400 chars, split it into sequential chunks.
  static Future<void> sendToken(
    ScannedDevice device, {
    required String token,
    String? clientId,
  }) async {
    final char = await _findCvaiChar(device, CvaiBle.wifiCredsCharUuid);
    const chunkSize = 380; // safe margin under 512-byte MTU

    String cleanToken = token.trim();
    if (cleanToken.startsWith('Bearer ')) {
      cleanToken = cleanToken.substring(7).trim();
    }

    if (cleanToken.length <= chunkSize) {
      final jsonStr = jsonEncode({
        'token': cleanToken,
        'access_token': cleanToken,
        'accessToken': cleanToken,
        'bearer_token': 'Bearer $cleanToken',
        if (clientId != null && clientId.isNotEmpty) ...{
          'client_id': clientId,
          'clientId': clientId,
        },
      });
      _log('Sending token (${jsonStr.length} B)');
      try {
        await char.write(utf8.encode(jsonStr));
        _log('Token sent successfully.');
      } catch (e) {
        throw BleException('Could not send token: $e');
      }
    } else {
      // Token is a long JWT — split into chunks
      _log('Token too long (${cleanToken.length} chars) — chunking.');
      final chunks = <String>[];
      for (var i = 0; i < cleanToken.length; i += chunkSize) {
        chunks.add(cleanToken.substring(i, (i + chunkSize).clamp(0, cleanToken.length)));
      }
      for (var i = 0; i < chunks.length; i++) {
        final jsonStr = jsonEncode({
          'token_chunk': chunks[i],
          'token': chunks[i],
          'access_token': chunks[i],
          'chunk': i,
          'total': chunks.length,
          if (clientId != null && clientId.isNotEmpty) 'client_id': clientId,
        });
        _log('Token chunk ${i + 1}/${chunks.length} (${jsonStr.length} B)');
        try {
          await char.write(utf8.encode(jsonStr));
          await Future<void>.delayed(const Duration(milliseconds: 200));
        } catch (e) {
          throw BleException('Could not send token chunk ${i + 1}: $e');
        }
      }
      _log('All token chunks sent.');
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
    final fbpDev = _bleDeviceCache[device.id] ??
        BluetoothDevice(remoteId: DeviceIdentifier(device.id));
    if (!fbpDev.isConnected) {
      throw BleException(
        'Bluetooth disconnected. Go back and pair the device again.',
      );
    }
    var services = await fbpDev.discoverServices();
    _log('Discovered ${services.length} services on "${device.name}" (${device.id}):');
    for (final s in services) {
      _log('  - Service: ${s.uuid.str}');
      for (final c in s.characteristics) {
        _log('      * Characteristic: ${c.uuid.str}');
      }
    }
    final targetServices = CvaiBle.serviceUuids.map((u) => u.toLowerCase()).toSet();
    var svc = services.where(
      (s) => targetServices.contains(s.uuid.str.toLowerCase()),
    );
    if (svc.isEmpty) {
      _log('CVAI service not found in cache. Clearing Android GATT cache and retrying...');
      try {
        await fbpDev.clearGattCache();
        await Future<void>.delayed(const Duration(milliseconds: 600));
        services = await fbpDev.discoverServices();
        _log('Re-discovered ${services.length} services on "${device.name}" (${device.id}) after cache clear:');
        for (final s in services) {
          _log('  - Service: ${s.uuid.str}');
          for (final c in s.characteristics) {
            _log('      * Characteristic: ${c.uuid.str}');
          }
        }
        svc = services.where(
          (s) => targetServices.contains(s.uuid.str.toLowerCase()),
        );
      } catch (e) {
        _log('Failed to clear GATT cache: $e');
      }
    }
    if (svc.isEmpty) {
      throw BleException(
        'This device is not a CVAI device — its Bluetooth services do '
        'not match. Pair the right one.',
      );
    }

    final selectedService = svc.first;
    // Map charUuid to allowed candidate UUIDs
    final candidates = <String>{charUuid.toLowerCase()};
    if (charUuid.toLowerCase() == CvaiBle.wifiListCharUuid.toLowerCase() ||
        charUuid.toLowerCase() == CvaiBle.legacyWifiListCharUuid.toLowerCase()) {
      candidates.addAll([
        CvaiBle.wifiListCharUuid.toLowerCase(),
        CvaiBle.legacyWifiListCharUuid.toLowerCase(),
      ]);
    } else if (charUuid.toLowerCase() == CvaiBle.wifiCredsCharUuid.toLowerCase() ||
        charUuid.toLowerCase() == CvaiBle.legacyWifiCredsCharUuid.toLowerCase()) {
      candidates.addAll([
        CvaiBle.wifiCredsCharUuid.toLowerCase(),
        CvaiBle.legacyWifiCredsCharUuid.toLowerCase(),
      ]);
    } else if (charUuid.toLowerCase() == CvaiBle.statusCharUuid.toLowerCase() ||
        charUuid.toLowerCase() == CvaiBle.legacyStatusCharUuid.toLowerCase()) {
      candidates.addAll([
        CvaiBle.statusCharUuid.toLowerCase(),
        CvaiBle.legacyStatusCharUuid.toLowerCase(),
      ]);
    }

    final chars = selectedService.characteristics.where(
      (c) => candidates.contains(c.uuid.str.toLowerCase()),
    );
    if (chars.isNotEmpty) {
      return chars.first;
    }

    // Fallback: match by position if characteristics list has 3 items
    if (candidates.contains(CvaiBle.wifiListCharUuid.toLowerCase()) &&
        selectedService.characteristics.isNotEmpty) {
      return selectedService.characteristics[0];
    }
    if (candidates.contains(CvaiBle.wifiCredsCharUuid.toLowerCase()) &&
        selectedService.characteristics.length > 1) {
      return selectedService.characteristics[1];
    }
    if (candidates.contains(CvaiBle.statusCharUuid.toLowerCase()) &&
        selectedService.characteristics.length > 2) {
      return selectedService.characteristics[2];
    }

    throw BleException(
      'Device is missing a required characteristic ($charUuid). '
      'It may be running an incompatible firmware.',
    );
  }

  static List<WifiNetwork> _decodeWifiList(List<int> bytes) {
    final str = utf8.decode(bytes, allowMalformed: true).trim();
    _log('Received raw WiFi list: "$str"');
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
      } else if (item is String && item.trim().isNotEmpty) {
        list.add(WifiNetwork(
          ssid: item.trim(),
          secured: true,
        ));
      }
    }
    return list;
  }

  static ProvisionStatus _decodeStatus(List<int> bytes) {
    final str = utf8.decode(bytes, allowMalformed: true).trim();
    _log('Received raw status notification: "$str"');
    if (str.isEmpty) {
      return const ProvisionStatus(
        state: ProvisionState.failed,
        message: 'Empty status from device.',
      );
    }
    // 1. Try to parse as JSON map first
    try {
      final data = jsonDecode(str);
      if (data is Map) {
        return ProvisionStatus.fromJson(data.cast<String, dynamic>());
      }
    } catch (_) {
      // Catch json parse error to fall back to plain-text matching
    }

    // 2. Parse as plain-text state
    final normalized = str.toLowerCase().replaceAll(RegExp(r'[-_]'), '');
    if (normalized == 'requesttoken' || normalized == 'token') {
      return const ProvisionStatus(
        state: ProvisionState.request_token,
        message: 'Requesting access token',
      );
    } else if (normalized == 'wifiok') {
      return const ProvisionStatus(
        state: ProvisionState.wifi_ok,
        message: 'Raspberry Pi connected to WiFi',
      );
    } else if (normalized == 'wififail' || normalized == 'wifiFailed') {
      return const ProvisionStatus(
        state: ProvisionState.wifi_fail,
        message: 'Raspberry Pi could not connect to the Wi-Fi network. '
            'Please check the Wi-Fi credentials and try again.',
      );
    } else if (normalized == 'connecting') {
      return const ProvisionStatus(
        state: ProvisionState.connecting,
        message: 'Connecting to WiFi',
      );
    } else if (normalized == 'connected') {
      return const ProvisionStatus(
        state: ProvisionState.connected,
        message: 'Connected to WiFi',
      );
    } else if (normalized == 'failed') {
      return const ProvisionStatus(
        state: ProvisionState.failed,
        message: 'WiFi connection failed',
      );
    }

    // Fallback logic for variations of token request text
    if (normalized.contains('token')) {
      return const ProvisionStatus(
        state: ProvisionState.request_token,
        message: 'Requesting access token (inferred)',
      );
    }

    return ProvisionStatus(
      state: ProvisionState.failed,
      message: 'Device sent unreadable status: $str',
    );
  }

  static String _humanizeBleError(Object e) {
    final s = e.toString();
    if (s.contains('android-code: 133') || s.contains('ANDROID_SPECIFIC_ERROR')) {
      return 'Could not reach the device over BLE. '
          'Please move closer and tap Try again.';
    }
    if (s.contains('android-code: 257') || s.contains('CONNECTION_LIMIT_EXCEEDED')) {
      return 'Too many Bluetooth connections. Disconnect another device and try again.';
    }
    if (s.toLowerCase().contains('timeout')) {
      return 'Connection timed out. Make sure the device is powered on and nearby.';
    }
    if (s.toLowerCase().contains('cancel')) return 'The connection was canceled.';
    if (s.toLowerCase().contains('null gatt')) {
      return 'This device does not expose a GATT server — try a different one.';
    }
    return 'Could not connect: $e';
  }

  // ---- internals --------------------------------------------------------

  static void _ensureWired() {
    if (_wired) return;
    _wired = true;

    // Immediately seed bonded/paired devices from the OS
    scheduleMicrotask(() => _seedBondedDevices());

    FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final id = r.device.remoteId.str;
        _bleDeviceCache[id] = r.device;

        final existing = _devices['ble:$id'];

        // Extract name carefully from advName, platformName, bondedNameCache, or existing name!
        final advName = r.advertisementData.advName.trim();
        final platName = r.device.platformName.trim();
        String name = advName.isNotEmpty ? advName : platName;
        if (name.isEmpty && _bondedNameCache.containsKey(id) && _bondedNameCache[id]!.isNotEmpty) {
          name = _bondedNameCache[id]!;
        }
        if (name.isEmpty && existing != null && existing.name.isNotEmpty) {
          name = existing.name; // Preserve known name! Never overwrite with empty
        }
        if (name.isNotEmpty) {
          _bondedNameCache[id] = name;
        }

        final isBonded = existing?.isBonded == true || _bondedNameCache.containsKey(id);

        final uuids = r.advertisementData.serviceUuids
            .map((g) => g.str.toLowerCase())
            .toList(growable: false);

        // Merge with any previously-seen UUIDs for this device — across
        // ScanResponse packets the advertisement contents can vary, so we
        // accumulate the union of what we've ever seen.
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
            label.toLowerCase().contains('raspberry') ||
            label.toLowerCase().contains('pi') ||
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
          isBonded: isBonded,
          serviceUuids: mergedUuids,
        );
      }
      _emitResults();
    });
    FlutterBluePlus.isScanning.listen((on) {
      _bleScanning = on;
      _scanningController.add(_bleScanning);
    });
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
