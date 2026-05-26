import 'dart:async';

import 'package:flutter/material.dart';
import '../../theme/app_icons.dart';

import '../../models/scanned_device.dart';
import '../../services/ble_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_app_bar.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';
import 'wifi_setup_screen.dart';

/// The name prefix the CVAI Pi/Mac peripheral advertises with.
/// Keep in sync with `_device_name()` in `app/services/ble_provisioning.py`
/// on the server.
const cvaiBleNamePrefix = 'CVAI-';

/// Drives an actual pair attempt against [device]:
///
/// - **BLE** → opens a GATT link via flutter_blue_plus / flutter_web_bluetooth.
/// - **Classic** → triggers the Android system pairing dialog and waits for
///   the OS to report the device as bonded.
class BlePairScreen extends StatefulWidget {
  const BlePairScreen({super.key, required this.device});

  final ScannedDevice device;

  @override
  State<BlePairScreen> createState() => _BlePairScreenState();
}

class _BlePairScreenState extends State<BlePairScreen> {
  BleConnectionState _state = BleConnectionState.connecting;
  String? _error;
  StreamSubscription<BleConnectionState>? _stateSub;
  Timer? _elapsedTimer;
  DateTime? _connectStartedAt;
  Duration _connectElapsed = Duration.zero;

  void _log(String message) {
    final ts = DateTime.now().toIso8601String();
    final name =
        widget.device.name.isNotEmpty ? widget.device.name : 'Unnamed device';
    debugPrint(
      '[BLE-UI][$ts] $message | $name | ${widget.device.kind.name.toUpperCase()} | ${widget.device.id}',
    );
  }

  @override
  void initState() {
    super.initState();
    _log('pair-screen opened');
    _stateSub = BleService.connectionState(widget.device).listen((s) {
      _log('state update=$s');
      if (!mounted) return;
      setState(() {
        _state = s;
        if (s != BleConnectionState.failed) _error = null;
      });
    });
    // Defer one frame so the screen mounts before any synchronous error
    // bubbles out of connect().
    WidgetsBinding.instance.addPostFrameCallback((_) => _attemptConnect());
  }

  @override
  void dispose() {
    _log('pair-screen disposed');
    _stateSub?.cancel();
    _elapsedTimer?.cancel();
    // Best-effort cleanup: drop the radio link when the user backs out.
    BleService.disconnect(widget.device);
    super.dispose();
  }

  Future<void> _attemptConnect() async {
    _log('connect attempt started');
    _elapsedTimer?.cancel();
    setState(() {
      _state = BleConnectionState.connecting;
      _error = null;
      _connectStartedAt = DateTime.now();
      _connectElapsed = Duration.zero;
    });
    // 100ms tick so the user can see the connection isn't instant.
    _elapsedTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || _connectStartedAt == null) return;
      if (_state != BleConnectionState.connecting) {
        _elapsedTimer?.cancel();
        return;
      }
      setState(() {
        _connectElapsed = DateTime.now().difference(_connectStartedAt!);
      });
    });
    try {
      await BleService.connect(widget.device);
      _log('connect attempt completed without throw');
    } on BleException catch (e) {
      _log('connect error=${e.message}');
      if (!mounted) return;
      _elapsedTimer?.cancel();
      setState(() {
        _state = BleConnectionState.failed;
        _error = e.message;
      });
    } catch (e) {
      _log('connect unexpected error=$e');
      if (!mounted) return;
      _elapsedTimer?.cancel();
      setState(() {
        _state = BleConnectionState.failed;
        _error = e.toString();
      });
    }
    _elapsedTimer?.cancel();
  }

  // ---- UI ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppAppBar(title: 'Pair Device', showBack: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              _iconCircle(),
              const SizedBox(height: 24),
              Text(
                _displayName,
                style: AppTextStyles.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                widget.device.id,
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _statusRow(),
              if (_error != null) ...[
                const SizedBox(height: 16),
                _errorCard(_error!),
              ],
              const Spacer(),
              _ctas(),
            ],
          ),
        ),
      ),
    );
  }

  String get _displayName =>
      widget.device.name.isNotEmpty ? widget.device.name : 'Unnamed device';

  Widget _iconCircle() {
    final (bg, fg, icon) = switch (_state) {
      BleConnectionState.connected => (
          AppColors.successBg,
          AppColors.success,
          LucideIcons.checkCircle2,
        ),
      BleConnectionState.failed => (
          AppColors.dangerBg,
          AppColors.danger,
          LucideIcons.alertCircle,
        ),
      BleConnectionState.disconnected => (
          AppColors.dangerBg,
          AppColors.danger,
          LucideIcons.bluetoothOff,
        ),
      BleConnectionState.connecting => (
          AppColors.infoBg,
          AppColors.info,
          LucideIcons.cpu,
        ),
    };
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, size: 56, color: fg),
    );
  }

  Widget _statusRow() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Row(
        key: ValueKey(_state),
        mainAxisSize: MainAxisSize.min,
        children: switch (_state) {
          BleConnectionState.connecting => [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
              const SizedBox(width: 8),
              Text(_busyLabel, style: AppTextStyles.caption),
            ],
          BleConnectionState.connected => [
              const Icon(LucideIcons.check,
                  size: 16, color: AppColors.success),
              const SizedBox(width: 6),
              Text(
                'Paired successfully',
                style: AppTextStyles.bodyStrong
                    .copyWith(color: AppColors.success),
              ),
            ],
          BleConnectionState.disconnected => [
              const Icon(LucideIcons.bluetoothOff,
                  size: 16, color: AppColors.danger),
              const SizedBox(width: 6),
              Text(
                'Connection lost',
                style: AppTextStyles.bodyStrong
                    .copyWith(color: AppColors.danger),
              ),
            ],
          BleConnectionState.failed => [
              const Icon(LucideIcons.alertCircle,
                  size: 16, color: AppColors.danger),
              const SizedBox(width: 6),
              Text(
                'Pairing failed',
                style: AppTextStyles.bodyStrong
                    .copyWith(color: AppColors.danger),
              ),
            ],
        },
      ),
    );
  }

  String get _busyLabel {
    final secs = (_connectElapsed.inMilliseconds / 1000).toStringAsFixed(1);
    if (widget.device.kind == BluetoothKind.classic) {
      return 'Waiting for system pairing… (${secs}s)';
    }
    return 'Connecting over Bluetooth… (${secs}s)';
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

  Widget _ctas() {
    switch (_state) {
      case BleConnectionState.connected:
        return PrimaryButton(
          label: 'Continue',
          icon: LucideIcons.arrowRight,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WifiSetupScreen(device: widget.device),
            ),
          ),
        );
      case BleConnectionState.failed:
      case BleConnectionState.disconnected:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrimaryButton(
              label: 'Try again',
              icon: LucideIcons.refreshCw,
              onPressed: _attemptConnect,
            ),
            const SizedBox(height: 10),
            SecondaryButton(
              label: 'Back to scan',
              icon: LucideIcons.arrowLeft,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      case BleConnectionState.connecting:
        return const PrimaryButton(
          label: 'Continue',
          icon: LucideIcons.arrowRight,
          onPressed: null,
        );
    }
  }
}
