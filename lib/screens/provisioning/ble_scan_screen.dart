import 'dart:async';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:flutter/material.dart';
import '../../theme/app_icons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/scanned_device.dart';
import '../../services/ble_service.dart';
import '../../services/cvai_ble_protocol.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_app_bar.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../dashboard/home_screen.dart';
import 'ble_pair_screen.dart';

class BleScanScreen extends StatefulWidget {
  const BleScanScreen({super.key});

  @override
  State<BleScanScreen> createState() => _BleScanScreenState();
}

class _BleScanScreenState extends State<BleScanScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  /// When true, the visible scan list (mobile) and the chooser filter
  /// (web) are restricted to CVAI-looking BLE peripherals so the user
  /// doesn't accidentally pair with random devices.
  bool _cvaiOnly = false;

  /// When true, anonymous BLE beacons without names are hidden so the user
  /// sees real devices (Raspberry Pi, named peripherals) instead of clutter.
  bool _hideUnnamed = true;

  // --- web: devices picked from the browser chooser ----------------------
  final List<ScannedDevice> _webDevices = [];
  bool _webScanning = false;

  // --- mobile: live BLE scan ---------------------------------------------
  /// null = permission not asked yet, true = granted, false = denied.
  bool? _btGranted;
  BleAdapterState _adapter = BleAdapterState.unknown;
  List<ScannedDevice> _results = const [];
  bool _scanning = false;
  StreamSubscription<List<ScannedDevice>>? _resultsSub;
  StreamSubscription<bool>? _scanningSub;
  StreamSubscription<BleAdapterState>? _adapterSub;

  void _log(String message) {
    final ts = DateTime.now().toIso8601String();
    debugPrint('[BLE-SCAN][$ts] $message');
  }

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _initMobile());
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _resultsSub?.cancel();
    _scanningSub?.cancel();
    _adapterSub?.cancel();
    if (!kIsWeb) BleService.stopScan();
    super.dispose();
  }

  // --- Mobile ------------------------------------------------------------

  Future<void> _initMobile() async {
    final statuses = await _requestBluetoothPermissions();

    final granted = statuses.values.every((s) => s.isGranted || s.isLimited);
    if (!mounted) return;
    setState(() => _btGranted = granted);

    if (!granted) {
      if (statuses.values.any((s) => s.isPermanentlyDenied)) {
        _showMessage('Bluetooth permission is blocked. Enable it in Settings.');
      }
      return;
    }

    _adapterSub = BleService.adapterState().listen((s) {
      if (!mounted) return;
      final wasOff = _adapter != BleAdapterState.on;
      setState(() => _adapter = s);
      if (s == BleAdapterState.on && wasOff) {
        // Bluetooth just came on (either at startup or after the user
        // turned it on) — kick the scan automatically with the current
        // filter setting.
        _startScan();
      } else if (s == BleAdapterState.off) {
        // Don't keep stale results around once the radio is off.
        BleService.stopScan();
        setState(() => _results = const []);
      }
    });
    _scanningSub = BleService.isScanning().listen((on) {
      if (mounted) setState(() => _scanning = on);
    });
    _resultsSub = BleService.scanResults().listen((list) {
      if (!mounted) return;
      final cvaiUuid = CvaiBle.serviceUuid.toLowerCase();
      // Keep BLE peripherals and any paired/bonded devices from the phone
      final visibleList = list.where((d) => d.kind == BluetoothKind.ble || d.isBonded).toList();
      final sorted = [...visibleList]..sort((a, b) {
        // Priority 1: CVAI / Raspberry Pi devices always at the very top
        final aCvai = _looksLikeCvai(a, cvaiUuid: cvaiUuid);
        final bCvai = _looksLikeCvai(b, cvaiUuid: cvaiUuid);
        if (aCvai != bCvai) return aCvai ? -1 : 1;

        // Priority 2: Paired / bonded devices in phone settings
        if (a.isBonded != b.isBonded) return a.isBonded ? -1 : 1;

        // Priority 3: Named devices before unnamed devices
        final aNamed = a.name.trim().isNotEmpty;
        final bNamed = b.name.trim().isNotEmpty;
        if (aNamed != bNamed) return aNamed ? -1 : 1;

        // Priority 4: Stronger signal (RSSI) first
        final rssiCmp = (b.rssi ?? -999).compareTo(a.rssi ?? -999);
        return rssiCmp;
      });
      setState(() => _results = sorted);
    });
  }

  Future<Map<Permission, PermissionStatus>>
      _requestBluetoothPermissions() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      final single = await [Permission.bluetooth].request();
      return single;
    }
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    if (BleService.requiresLegacyLocationPermission) {
      statuses[Permission.locationWhenInUse] =
          await Permission.locationWhenInUse.request();
    }
    return statuses;
  }

  Future<void> _startScan() async {
    if (_adapter != BleAdapterState.on) return; // adapter listener will retry
    try {
      _log('startScan requested cvaiOnly=$_cvaiOnly');
      await BleService.startScan(cvaiOnly: _cvaiOnly);
      _log('startScan finished');
    } on BleException catch (e) {
      // The adapter panel already covers "Bluetooth is off" — don't
      // double-message in that case.
      if (_adapter == BleAdapterState.off) return;
      _log('startScan error=${e.message}');
      _showMessage(e.message);
    } catch (e) {
      _log('startScan unexpected error=$e');
      _showMessage('Could not start scan: $e');
    }
  }

  Future<void> _requestTurnOn() async {
    try {
      await BleService.turnOn();
      // The adapter stream will fire `on` next and auto-start the scan.
    } on BleException catch (e) {
      _showMessage(e.message);
    }
  }

  // --- Web ---------------------------------------------------------------

  Future<void> _scanWeb() async {
    setState(() => _webScanning = true);
    try {
      final device = await BleService.requestDevice(
        namePrefix: _cvaiOnly ? cvaiBleNamePrefix : null,
      );
      if (!mounted) return;
      if (device.name.isEmpty) {
        setState(() => _webScanning = false);
        _showMessage('That device has no name — skipped.');
        return;
      }
      setState(() {
        _webScanning = false;
        if (!_webDevices.any((d) => d.id == device.id)) {
          _webDevices.add(device);
        }
      });
    } on BleException catch (e) {
      if (!mounted) return;
      setState(() => _webScanning = false);
      _showMessage(e.message);
    }
  }

  // --- Shared ------------------------------------------------------------

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _openPair(ScannedDevice device) {
    final name = device.name.isNotEmpty ? device.name : 'Unnamed device';
    _log('openPair $name | ${device.kind.name.toUpperCase()} | ${device.id}');
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BlePairScreen(device: device)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppAppBar(
        title: 'Pair Device',
        showBack: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            ),
            child: const Text('Skip', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              ScaleTransition(
                scale: Tween<double>(begin: 1, end: 1.1).animate(
                  CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                ),
                child: Container(
                  width: 132,
                  height: 132,
                  decoration: const BoxDecoration(
                    color: AppColors.infoBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.bluetooth,
                    size: 64,
                    color: AppColors.info,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (kIsWeb) _webBody() else _mobileBody(),
            ],
          ),
        ),
      ),
    );
  }

  // --- Mobile UI ---------------------------------------------------------

  Widget _mobileBody() {
    if (_btGranted == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: CircularProgressIndicator(),
      );
    }
    if (_btGranted == false) {
      return _permissionDenied();
    }
    if (_adapter == BleAdapterState.off) {
      return _bluetoothOffPanel();
    }

    // Filter rules:
    //  - With "Only CVAI" ON: keep peripherals that advertise our
    //    service UUID or whose name starts with CVAI- or contains raspberry/pi.
    //  - With "Hide Unnamed" ON: hide anonymous beacons that have no name.
    final cvaiUuid = CvaiBle.serviceUuid.toLowerCase();
    final visible = _results
        .where((d) {
          if (_cvaiOnly) return _looksLikeCvai(d, cvaiUuid: cvaiUuid);
          if (_hideUnnamed) {
            final isNamed = d.name.trim().isNotEmpty;
            final isCvai = _looksLikeCvai(d, cvaiUuid: cvaiUuid);
            if (!isNamed && !isCvai) return false;
          }
          return true;
        })
        .toList(growable: false);
    final hiddenCount = _results.length - visible.length;

    return Column(
      children: [
        _filterToggle(),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_scanning) ...[
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text('Scanning for devices…', style: AppTextStyles.caption),
            ] else ...[
              Text(
                '${visible.length} device${visible.length == 1 ? '' : 's'} '
                'found${_cvaiOnly ? ' (CVAI only)' : ''}',
                style: AppTextStyles.caption,
              ),
              if (hiddenCount > 0) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => setState(() => _hideUnnamed = !_hideUnnamed),
                  child: Text(
                    '($hiddenCount unnamed hidden)',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
        const SizedBox(height: 16),
        if (visible.isEmpty && !_scanning)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              _cvaiOnly
                  ? 'No CVAI devices nearby. The device must be powered on '
                      'and in setup mode.'
                  : (_hideUnnamed && hiddenCount > 0)
                      ? 'No named devices found yet ($hiddenCount unnamed beacons detected). '
                          'Tap above to show unnamed devices or scan again.'
                      : 'No Bluetooth devices nearby. Make sure your CVAI device '
                          'is powered on and discoverable, then scan again.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
          ),
        ...visible.map(_deviceCard),
        const SizedBox(height: 8),
        PrimaryButton(
          label: 'Scan again',
          icon: LucideIcons.refreshCw,
          fullWidth: false,
          loading: _scanning,
          onPressed: _scanning ? null : _startScan,
        ),
      ],
    );
  }

  Widget _filterToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(LucideIcons.eyeOff, size: 18, color: AppColors.info),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hide unnamed devices', style: AppTextStyles.bodyStrong),
                    Text(
                      'Hides empty beacons so Raspberry Pi and named devices stand out.',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _hideUnnamed,
                onChanged: (v) {
                  setState(() => _hideUnnamed = v);
                },
              ),
            ],
          ),
          const Divider(height: 12),
          Row(
            children: [
              const Icon(LucideIcons.filter, size: 18, color: AppColors.info),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Only CVAI devices', style: AppTextStyles.bodyStrong),
                    Text(
                      'Filter strictly to CVAI service or "CVAI-" peripherals.',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _cvaiOnly,
                onChanged: (v) {
                  setState(() => _cvaiOnly = v);
                  // Restart the OS-level scan with the new filter immediately
                  BleService.stopScan();
                  setState(() => _results = const []);
                  _startScan();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bluetoothOffPanel() {
    // On Android we can pop the system "turn on Bluetooth" prompt directly.
    // On iOS / desktop / web there's no such API — the user has to flip it
    // themselves in system settings.
    final canPromptToTurnOn = BleService.canPromptToTurnOn;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.dangerBg,
            shape: BoxShape.circle,
          ),
          child: const Icon(LucideIcons.bluetoothOff,
              size: 36, color: AppColors.danger),
        ),
        const SizedBox(height: 16),
        Text('Bluetooth is off', style: AppTextStyles.bodyStrong),
        const SizedBox(height: 6),
        Text(
          canPromptToTurnOn
              ? 'CVAI needs Bluetooth to find your device. Turn it on to '
                  'continue scanning.'
              : 'CVAI needs Bluetooth to find your device. Turn it on from '
                  'system settings, then come back here.',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: canPromptToTurnOn ? 'Turn on Bluetooth' : 'Open Settings',
          icon: LucideIcons.bluetooth,
          fullWidth: false,
          onPressed: canPromptToTurnOn ? _requestTurnOn : openAppSettings,
        ),
      ],
    );
  }

  Widget _permissionDenied() {
    final needsLocation = BleService.requiresLegacyLocationPermission;
    return Column(
      children: [
        Text('Bluetooth permission needed', style: AppTextStyles.bodyStrong),
        const SizedBox(height: 6),
        Text(
          needsLocation
              ? 'CVAI needs Bluetooth and Location access on this Android '
                  'version to scan nearby devices.'
              : 'CVAI needs Bluetooth access to find and pair with your '
                  'device. Grant the permission to continue.',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Allow Bluetooth',
          icon: LucideIcons.bluetooth,
          fullWidth: false,
          onPressed: () async {
            await openAppSettings();
            _initMobile();
          },
        ),
      ],
    );
  }

  // --- Web UI ------------------------------------------------------------

  bool _looksLikeCvai(ScannedDevice device, {required String cvaiUuid}) {
    if (device.serviceUuids.contains(cvaiUuid)) return true;
    final upper = device.name.toUpperCase();
    return upper.startsWith(cvaiBleNamePrefix) ||
        upper.contains('RASPBERRY') ||
        upper.contains('PI');
  }

  Widget _webBody() {
    return Column(
      children: [
        Text(
          _webDevices.isEmpty
              ? 'Scan to find your CVAI device'
              : 'Selected devices',
          style: AppTextStyles.bodyStrong,
        ),
        const SizedBox(height: 6),
        Text(
          'Tapping Scan opens the browser\'s Bluetooth picker with the real '
          'devices around you. Pick one to add it here.',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: _webDevices.isEmpty ? 'Scan for devices' : 'Scan again',
          icon: LucideIcons.bluetooth,
          fullWidth: false,
          loading: _webScanning,
          onPressed: _webScanning ? null : _scanWeb,
        ),
        const SizedBox(height: 24),
        ..._webDevices.map(_deviceCard),
      ],
    );
  }

  Widget _deviceCard(ScannedDevice device) {
    final cvaiUuid = CvaiBle.serviceUuid.toLowerCase();
    final isCvai = _looksLikeCvai(device, cvaiUuid: cvaiUuid);
    final isPi = device.name.toLowerCase().contains('raspberry') ||
        device.name.toLowerCase().contains('pi');
    final hasName = device.name.trim().isNotEmpty;
    final displayName = hasName
        ? device.name.trim()
        : isCvai
            ? 'Raspberry Pi (CVAI)'
            : 'BLE Device (${device.id.length > 5 ? device.id.substring(device.id.length - 5) : device.id})';
    final subtitleParts = <String>[];
    if (device.rssi != null) subtitleParts.add('Signal ${device.rssi} dBm');
    subtitleParts.add(device.id);
    final subtitle = subtitleParts.join(' · ');

    final highlight = isCvai || isPi;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: () => _openPair(device),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: highlight ? AppColors.successBg : AppColors.infoBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                highlight ? LucideIcons.cpu : LucideIcons.bluetooth,
                size: 20,
                color: highlight ? AppColors.success : AppColors.info,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: AppTextStyles.bodyStrong.copyWith(
                            color: highlight ? AppColors.primary : null,
                            fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (highlight) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.successBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Pi / CVAI',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      _kindBadge(device.kind),
                      if (device.isBonded) ...[
                        const SizedBox(width: 4),
                        _bondedBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _kindBadge(BluetoothKind kind) {
    final label = kind == BluetoothKind.ble ? 'BLE' : 'Classic';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.infoBg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.info,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _bondedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.infoBg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Paired',
        style: AppTextStyles.caption.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}
