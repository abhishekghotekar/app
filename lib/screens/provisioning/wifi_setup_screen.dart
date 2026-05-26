import 'dart:async';
import 'package:wifi_scan/wifi_scan.dart';

import 'package:flutter/material.dart';
import '../../theme/app_icons.dart';

import '../../models/scanned_device.dart';
import '../../models/wifi_network.dart';
import '../../services/ble_service.dart';
import '../../services/device_storage.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_app_bar.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';
import 'provisioning_success_screen.dart';

/// Drives the WiFi half of provisioning against the paired CVAI device:
///
/// 1. On entry, reads the device's WiFi-list characteristic over BLE and
///    populates the dropdown with what the device can actually see.
/// 2. User picks an SSID + types the password.
/// 3. On Send, writes the JSON credentials to the device, then listens to
///    the device's status notifications.
/// 4. On `connected`, persists IP + token to [DeviceStorage] and navigates
///    to the success screen.
class WifiSetupScreen extends StatefulWidget {
  const WifiSetupScreen({super.key, required this.device});

  final ScannedDevice device;

  @override
  State<WifiSetupScreen> createState() => _WifiSetupScreenState();
}

enum _Phase { loadingList, ready, sending, joining, done, failed }

class _WifiSetupScreenState extends State<WifiSetupScreen> {
  _Phase _phase = _Phase.loadingList;
  List<WifiNetwork> _networks = const [];
  WifiNetwork? _selected;
  final _password = TextEditingController();
  final _ssidController = TextEditingController();
  bool _manualSsid = false;
  bool _obscure = true;
  String? _error;
  String? _sentSsid;
  StreamSubscription<ProvisionStatus>? _statusSub;

  @override
  void initState() {
    super.initState();
    _loadList();
    _subscribeStatus();
  }

  @override
  void dispose() {
    _password.dispose();
    _ssidController.dispose();
    _statusSub?.cancel();
    super.dispose();
  }

  // ---- BLE calls --------------------------------------------------------

  Future<void> _loadList() async {
    setState(() {
      _phase = _Phase.loadingList;
      _error = null;
    });
    try {
      List<WifiNetwork> list = [];
      final canScan = await WiFiScan.instance.canStartScan(askPermissions: true);
      if (canScan == CanStartScan.yes) {
        await WiFiScan.instance.startScan();
        // Allow a brief moment for the scanner to populate results
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      
      final results = await WiFiScan.instance.getScannedResults();
      final mapped = results.map((ap) {
        final caps = ap.capabilities.toUpperCase();
        final secured = caps.contains('WPA') || caps.contains('WEP') || caps.contains('PSK');
        return WifiNetwork(
          ssid: ap.ssid,
          rssi: ap.level,
          secured: secured,
        );
      }).where((net) => net.ssid.isNotEmpty).toList();

      final unique = <String, WifiNetwork>{};
      for (final net in mapped) {
        final existing = unique[net.ssid];
        if (existing == null || (net.rssi ?? -999) > (existing.rssi ?? -999)) {
          unique[net.ssid] = net;
        }
      }
      list = unique.values.toList()
        ..sort((a, b) => (b.rssi ?? -999).compareTo(a.rssi ?? -999));

      if (!mounted) return;
      setState(() {
        _networks = list;
        _selected = list.isNotEmpty ? list.first : null;
        _phase = list.isEmpty ? _Phase.failed : _Phase.ready;
        _error = list.isEmpty
            ? 'No WiFi networks found by your phone. Turn on your WiFi and Location, then try again.'
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _error = 'Failed to scan WiFi on phone: $e';
      });
    }
  }

  void _subscribeStatus() {
    _statusSub = BleService.provisioningStatus(widget.device).listen(
      _handleStatus,
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _phase = _Phase.failed;
          _error = e.toString();
        });
      },
    );
  }

  Future<void> _send() async {
    final ssid = _manualSsid ? _ssidController.text.trim() : _selected?.ssid;
    if (ssid == null || ssid.isEmpty) {
      setState(() => _error = 'Enter the WiFi name (SSID) to continue.');
      return;
    }
    final secured = _manualSsid ? _password.text.isNotEmpty : _selected?.secured == true;
    if (secured && _password.text.isEmpty) {
      setState(() => _error = 'Enter the WiFi password to continue.');
      return;
    }
    setState(() {
      _phase = _Phase.sending;
      _error = null;
      _sentSsid = ssid;
    });
    try {
      await BleService.sendWifiCredentials(
        widget.device,
        ssid: ssid,
        password: _password.text,
      );
      // Now we wait for the status notification to flip to connecting →
      // connected/failed; _handleStatus drives the rest.
      if (!mounted) return;
      setState(() => _phase = _Phase.joining);
    } on BleException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _error = e.message;
      });
    }
  }

  Future<void> _handleStatus(ProvisionStatus status) async {
    if (!mounted) return;
    switch (status.state) {
      case ProvisionState.connecting:
        setState(() => _phase = _Phase.joining);
        break;
      case ProvisionState.connected:
        await _onConnected(status);
        break;
      case ProvisionState.failed:
        setState(() {
          _phase = _Phase.failed;
          _error = status.message ?? 'The device could not join that network.';
        });
        break;
    }
  }

  Future<void> _onConnected(ProvisionStatus status) async {
    final ip = status.ip ?? '';
    final token = status.token ?? '';
    if (ip.isEmpty || token.isEmpty) {
      setState(() {
        _phase = _Phase.failed;
        _error = 'Device said it joined but did not send its IP/token.';
      });
      return;
    }
    await DeviceStorage.save(
      bleId: widget.device.id,
      name: widget.device.name.isNotEmpty ? widget.device.name : 'CVAI device',
      ip: ip,
      token: token,
    );
    if (!mounted) return;
    setState(() => _phase = _Phase.done);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ProvisioningSuccessScreen(
          deviceName: widget.device.name.isNotEmpty
              ? widget.device.name
              : 'CVAI device',
          ip: ip,
          ssid: _sentSsid ?? _selected?.ssid ?? '',
        ),
      ),
    );
  }

  // ---- UI ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppAppBar(title: 'Connect to WiFi', showBack: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Center(child: _iconCircle()),
              const SizedBox(height: 24),
              _phaseBody(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconCircle() {
    final (bg, fg, icon) = switch (_phase) {
      _Phase.done => (
          AppColors.successBg,
          AppColors.success,
          LucideIcons.checkCircle2,
        ),
      _Phase.failed => (
          AppColors.dangerBg,
          AppColors.danger,
          LucideIcons.wifiOff,
        ),
      _ => (AppColors.infoBg, AppColors.info, LucideIcons.wifi),
    };
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, size: 44, color: fg),
    );
  }

  Widget _phaseBody() {
    switch (_phase) {
      case _Phase.loadingList:
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Loading WiFi networks from the device…',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        );
      case _Phase.failed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _errorCard(_error ?? 'Something went wrong.'),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Try again',
              icon: LucideIcons.refreshCw,
              onPressed: _loadList,
            ),
            const SizedBox(height: 10),
            SecondaryButton(
              label: 'Enter WiFi Manually',
              icon: LucideIcons.pencil,
              onPressed: () {
                setState(() {
                  _manualSsid = true;
                  _phase = _Phase.ready;
                  _error = null;
                });
              },
            ),
            const SizedBox(height: 10),
            SecondaryButton(
              label: 'Back',
              icon: LucideIcons.arrowLeft,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      case _Phase.joining:
        return Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _selected != null
                  ? 'Device is joining "${_selected!.ssid}"…'
                  : 'Device is joining your network…',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyStrong,
            ),
            const SizedBox(height: 6),
            Text(
              'This usually takes 5–15 seconds. The device will report back '
              'once it has an IP on your network.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
          ],
        );
      case _Phase.done:
        return const SizedBox.shrink();
      case _Phase.ready:
      case _Phase.sending:
        return _form();
    }
  }

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_manualSsid) ...[
          AppTextField(
            label: 'WiFi Name (SSID)',
            hint: 'Enter your WiFi name',
            prefixIcon: LucideIcons.wifi,
            controller: _ssidController,
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _manualSsid = false;
                  _error = null;
                });
              },
              icon: const Icon(Icons.list, size: 16),
              label: const Text('Select from list'),
            ),
          ),
        ] else ...[
          Text('Network', style: AppTextStyles.caption),
          const SizedBox(height: 6),
          _SsidDropdown(
            networks: _networks,
            value: _selected,
            onChanged: (n) {
              setState(() {
                _selected = n;
                _error = null;
              });
            },
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _manualSsid = true;
                  _error = null;
                });
              },
              icon: const Icon(LucideIcons.pencil, size: 14),
              label: const Text('Enter WiFi name manually'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (_manualSsid || (_selected?.secured ?? true))
          AppTextField(
            label: 'WiFi Password',
            hint: 'Enter network password',
            prefixIcon: LucideIcons.lock,
            controller: _password,
            obscure: _obscure,
            suffix: IconButton(
              icon: Icon(
                _obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                size: 18,
                color: AppColors.textSecondary,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.successBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.unlock,
                    size: 18, color: AppColors.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This is an open network — no password needed.',
                    style: AppTextStyles.caption,
                  ),
                ),
              ],
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _errorCard(_error!),
        ],
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.infoBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.info,
                  size: 18, color: AppColors.info),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your WiFi credentials are sent over Bluetooth to the '
                  'device and never leave your phone otherwise.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primaryDark,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Send to Device',
          loading: _phase == _Phase.sending,
          onPressed: _phase == _Phase.sending ? null : _send,
        ),
      ],
    );
  }

  Widget _errorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.alertTriangle,
              size: 18, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SsidDropdown extends StatelessWidget {
  const _SsidDropdown({
    required this.networks,
    required this.value,
    required this.onChanged,
  });

  final List<WifiNetwork> networks;
  final WifiNetwork? value;
  final ValueChanged<WifiNetwork> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value?.ssid,
          isExpanded: true,
          icon: const Icon(LucideIcons.chevronDown,
              size: 18, color: AppColors.textSecondary),
          style: AppTextStyles.body,
          borderRadius: BorderRadius.circular(8),
          items: [
            for (final n in networks)
              DropdownMenuItem(
                value: n.ssid,
                child: Row(
                  children: [
                    Icon(
                      n.secured ? LucideIcons.wifi : LucideIcons.wifi,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        n.ssid,
                        style: AppTextStyles.body,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (n.rssi != null)
                      Text(
                        '${n.rssi} dBm',
                        style: AppTextStyles.caption,
                      ),
                    if (!n.secured) ...[
                      const SizedBox(width: 6),
                      const Icon(LucideIcons.unlock,
                          size: 14, color: AppColors.success),
                    ],
                  ],
                ),
              ),
          ],
          onChanged: (s) {
            if (s == null) return;
            final net = networks.firstWhere((n) => n.ssid == s);
            onChanged(net);
          },
        ),
      ),
    );
  }
}
