import 'dart:async';
import 'dart:convert' show jsonDecode, jsonEncode, utf8;
import 'dart:typed_data' show ByteData, Uint8List;

import 'package:flutter_web_bluetooth/flutter_web_bluetooth.dart';

import '../models/scanned_device.dart';
import '../models/wifi_network.dart';
import 'cvai_ble_protocol.dart';

/// Web Bluetooth, backed by flutter_web_bluetooth.
///
/// The browser does not allow a web page to silently list nearby devices, so
/// scanning here means opening the browser's own device-chooser popup.
class BleService {
  BleService._();

  // The native BluetoothDevice handles we got back from the chooser. The
  // pair screen looks these up by id to actually open a GATT link.
  static final Map<String, BluetoothDevice> _webCache = {};

  // Pair-attempt state — one broadcast stream per device id.
  static final Map<String, StreamController<BleConnectionState>>
      _connectionControllers = {};
  static final Map<String, StreamSubscription<bool>> _connectionSubs = {};

  static Future<bool> isSupported() async =>
      FlutterWebBluetooth.instance.isBluetoothApiSupported;

  static bool get requiresLegacyLocationPermission => false;

  static Stream<BleAdapterState> adapterState() =>
      FlutterWebBluetooth.instance.isAvailable
          .map((a) => a ? BleAdapterState.on : BleAdapterState.off);

  /// Web has no continuous scan — results come from [requestDevice] instead.
  static Stream<List<ScannedDevice>> scanResults() =>
      const Stream<List<ScannedDevice>>.empty();

  static Stream<bool> isScanning() => Stream<bool>.value(false);

  /// Web has no continuous BLE scan — the chooser opens via
  /// [requestDevice]. The [cvaiOnly] flag is accepted only to keep the
  /// API uniform with mobile; pass it through to `requestDevice` when
  /// you call that.
  static Future<void> startScan({bool cvaiOnly = false}) async {}

  static Future<void> stopScan() async {}

  /// Web cannot pop a system Bluetooth dialog.
  static bool get canPromptToTurnOn => false;

  /// Browsers can't toggle Bluetooth — the user has to do it themselves.
  static Future<void> turnOn() async {
    throw BleException(
      'Turn Bluetooth on from your system settings, then try again.',
    );
  }

  /// Opens the browser's Bluetooth chooser and returns the picked device.
  ///
  /// When [cvaiOnly] is true (the common case during provisioning), the
  /// chooser is filtered to peripherals advertising the CVAI service
  /// UUID — name-prefix filtering doesn't work on macOS peripherals
  /// because the OS overrides the advertised local name.
  static Future<ScannedDevice> requestDevice({
    String? namePrefix,
    bool cvaiOnly = false,
  }) async {
    if (!FlutterWebBluetooth.instance.isBluetoothApiSupported) {
      throw BleException(
        'This browser does not support Web Bluetooth. Use Chrome or Edge.',
      );
    }

    // Web Bluetooth requires us to *declare* the GATT services we plan to
    // access; otherwise even a successful chooser pick gives us no service
    // access. We always list the CVAI provisioning service so the WiFi
    // setup step can read/write its characteristics after pairing.
    const optionalServices = [CvaiBle.serviceUuid];
    final RequestOptionsBuilder options;
    if (cvaiOnly) {
      options = RequestOptionsBuilder(
        [RequestFilterBuilder(services: [CvaiBle.serviceUuid])],
        optionalServices: optionalServices,
      );
    } else if (namePrefix != null) {
      options = RequestOptionsBuilder(
        [RequestFilterBuilder(namePrefix: namePrefix)],
        optionalServices: optionalServices,
      );
    } else {
      options = RequestOptionsBuilder.acceptAllDevices(
        optionalServices: optionalServices,
      );
    }

    try {
      final device =
          await FlutterWebBluetooth.instance.requestDevice(options);
      _webCache[device.id] = device;
      return ScannedDevice(
        id: device.id,
        name: (device.name ?? '').trim(),
        kind: BluetoothKind.ble,
      );
    } catch (e) {
      // The package's error classes aren't exported, so match by type name.
      final type = e.runtimeType.toString();
      if (type == 'UserCancelledDialogError') {
        throw BleException('No device selected.');
      }
      if (type == 'BluetoothAdapterNotAvailable') {
        throw BleException('Bluetooth is turned off or unavailable.');
      }
      throw BleException('Could not access Bluetooth: $e');
    }
  }

  /// Live pair-attempt state for a device that was picked via [requestDevice].
  static Stream<BleConnectionState> connectionState(ScannedDevice device) =>
      _controllerFor(device.id).stream;

  /// Open the GATT link for the device the user just picked.
  static Future<void> connect(ScannedDevice device) async {
    final native = _webCache[device.id];
    final ctl = _controllerFor(device.id);
    if (native == null) {
      ctl.add(BleConnectionState.failed);
      throw BleException(
        'This device session expired. Tap "Scan" again to pick it.',
      );
    }
    ctl.add(BleConnectionState.connecting);

    try {
      // Do the actual GATT connect first. We intentionally subscribe to
      // the `connected` stream AFTER this resolves — otherwise the
      // stream's replay of the current state would flip the UI to
      // "connected" without us actually doing any work for devices the
      // browser already had a session with.
      await native.connect(timeout: const Duration(seconds: 15));
      if (!ctl.isClosed) ctl.add(BleConnectionState.connected);

      await _connectionSubs[device.id]?.cancel();
      _connectionSubs[device.id] = native.connected.skip(1).listen((on) {
        if (ctl.isClosed) return;
        if (!on) ctl.add(BleConnectionState.disconnected);
      });
    } catch (e) {
      if (!ctl.isClosed) ctl.add(BleConnectionState.failed);
      throw BleException(_humanize(e));
    }
  }

  static Future<void> disconnect(ScannedDevice device) async {
    final native = _webCache[device.id];
    if (native == null) return;
    try {
      native.disconnect();
    } catch (_) {
      // Best-effort.
    }
  }

  static StreamController<BleConnectionState> _controllerFor(String id) {
    return _connectionControllers.putIfAbsent(
      id,
      () => StreamController<BleConnectionState>.broadcast(),
    );
  }

  // ---- CVAI provisioning (web) -----------------------------------------

  static Future<List<WifiNetwork>> listWifiNetworks(
    ScannedDevice device,
  ) async {
    final char = await _findCvaiChar(device, CvaiBle.wifiListCharUuid);
    final data = await char.readValue();
    return _decodeWifiList(data);
  }

  static Future<void> sendWifiCredentials(
    ScannedDevice device, {
    required String ssid,
    required String password,
  }) async {
    final char = await _findCvaiChar(device, CvaiBle.wifiCredsCharUuid);
    final jsonMap = {
      'ssid': ssid,
      'password': password,
      'psk': password,
      'pass': password,
      'pwd': password,
    };
    final payload = Uint8List.fromList(
      utf8.encode(jsonEncode(jsonMap)),
    );
    try {
      await char.writeValueWithResponse(payload);
    } catch (e) {
      throw BleException('Could not send credentials: $e');
    }
  }

  static Future<void> sendToken(
    ScannedDevice device, {
    required String token,
  }) async {
    final char = await _findCvaiChar(device, CvaiBle.wifiCredsCharUuid);
    final formats = [
      {'token': token},
      {'access_token': token},
      {'accessToken': token},
    ];

    for (final map in formats) {
      final payload = Uint8List.fromList(
        utf8.encode(jsonEncode(map)),
      );
      try {
        await char.writeValueWithResponse(payload);
        // Small delay to let the device process the write
        await Future<void>.delayed(const Duration(milliseconds: 150));
      } catch (e) {
        throw BleException('Could not send token: $e');
      }
    }
  }

  static Stream<ProvisionStatus> provisioningStatus(
    ScannedDevice device,
  ) async* {
    final char = await _findCvaiChar(device, CvaiBle.statusCharUuid);
    try {
      await char.startNotifications();
    } catch (e) {
      throw BleException('Device refused status updates: $e');
    }
    yield* char.value.map(_decodeStatus);
  }

  static Future<BluetoothCharacteristic> _findCvaiChar(
    ScannedDevice device,
    String charUuid,
  ) async {
    final native = _webCache[device.id];
    if (native == null) {
      throw BleException(
        'Bluetooth session expired. Go back and pair the device again.',
      );
    }
    final services = await native.discoverServices();
    final svc = services.where(
      (s) => s.uuid.toLowerCase() == CvaiBle.serviceUuid.toLowerCase(),
    );
    if (svc.isEmpty) {
      throw BleException(
        'This device is not a CVAI device — its Bluetooth services do '
        'not match. Pair the right one.',
      );
    }
    final chars = await svc.first.getCharacteristics();
    final match = chars.where(
      (c) => c.uuid.toLowerCase() == charUuid.toLowerCase(),
    );
    if (match.isEmpty) {
      throw BleException(
        'Device is missing a required characteristic ($charUuid).',
      );
    }
    return match.first;
  }

  static List<WifiNetwork> _decodeWifiList(ByteData data) {
    if (data.lengthInBytes == 0) return const [];
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final str = utf8.decode(bytes, allowMalformed: true).trim();
    if (str.isEmpty) return const [];
    dynamic decoded;
    try {
      decoded = jsonDecode(str);
    } catch (_) {
      throw BleException('Device sent malformed WiFi data.');
    }
    if (decoded is! List) {
      throw BleException('Device sent unexpected WiFi data shape.');
    }
    final list = <WifiNetwork>[];
    for (final item in decoded) {
      if (item is Map) {
        final net = WifiNetwork.fromJson(item.cast<String, dynamic>());
        if (net.ssid.isNotEmpty) list.add(net);
      }
    }
    return list;
  }

  static ProvisionStatus _decodeStatus(ByteData data) {
    if (data.lengthInBytes == 0) {
      return const ProvisionStatus(
        state: ProvisionState.failed,
        message: 'Empty status from device.',
      );
    }
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final str = utf8.decode(bytes, allowMalformed: true).trim();
    // 1. Try to parse as JSON map first
    try {
      final decoded = jsonDecode(str);
      if (decoded is Map) {
        return ProvisionStatus.fromJson(decoded.cast<String, dynamic>());
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

  static String _humanize(Object e) {
    final type = e.runtimeType.toString();
    if (e is TimeoutException || type.contains('Timeout')) {
      return 'The device did not respond in time.';
    }
    if (type == 'NetworkError') {
      return 'The device refused the connection or is out of range.';
    }
    return 'Could not connect: $e';
  }
}
