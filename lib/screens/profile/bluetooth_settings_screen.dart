/// BlueSnap Bluetooth Settings Screen
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../../services/permission_service.dart';
import '../../widgets/shared_widgets.dart';
import 'diagnostics_screen.dart';

class BluetoothSettingsScreen extends ConsumerStatefulWidget {
  const BluetoothSettingsScreen({super.key});

  @override
  ConsumerState<BluetoothSettingsScreen> createState() => _BluetoothSettingsScreenState();
}

class _BluetoothSettingsScreenState extends ConsumerState<BluetoothSettingsScreen> {
  final _permissionService = PermissionService();
  Map<String, bool> _permissionStatus = {};

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final status = await _permissionService.getPermissionStatus();
    setState(() => _permissionStatus = status);
  }

  @override
  Widget build(BuildContext context) {
    final bt = ref.watch(bluetoothProvider);

    return Scaffold(
      backgroundColor: BlueSnapTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: BlueSnapTheme.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: BlueSnapTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Bluetooth Settings', style: BlueSnapTheme.headingM),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Diagnostics Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
                    );
                  },
                  icon: const Icon(Icons.bug_report, size: 20),
                  label: const Text('Run Diagnostics'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BlueSnapTheme.accentOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // ── Connection info ─────────────────
              const Text('Connection', style: BlueSnapTheme.headingS),
              const SizedBox(height: 8),
              Text(
                'BlueSnap discovers people around you over Bluetooth using '
                'Google Nearby Connections. You need at least two devices with '
                'the app to see each other.',
                style: BlueSnapTheme.bodyS,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: BlueSnapTheme.bgCard,
                  borderRadius: BorderRadius.circular(BlueSnapTheme.radiusL),
                  border: Border.all(color: BlueSnapTheme.border, width: 0.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bluetooth_searching, color: BlueSnapTheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bt.isScanning ? 'Discovering nearby' : 'Idle',
                            style: BlueSnapTheme.bodyM.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text('${bt.deviceCount} device(s) in range',
                              style: BlueSnapTheme.caption),
                        ],
                      ),
                    ),
                    Switch(
                      value: bt.isScanning,
                      activeThumbColor: BlueSnapTheme.primary,
                      onChanged: (on) async {
                        if (on) {
                          final ok = await _permissionService.hasBluetoothPermissions() ||
                              await _permissionService.requestBluetoothPermissions();
                          if (!ok) {
                            if (context.mounted) {
                              showAppSnack(context,
                                  'Bluetooth permissions are required to discover people',
                                  icon: Icons.lock_outline_rounded, isError: true);
                            }
                            return;
                          }
                          await bt.startScan();
                        } else {
                          await bt.stopScan();
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Permissions ──────────────────────
              const Text('Permissions', style: BlueSnapTheme.headingS),
              const SizedBox(height: 16),
              _permissionTile(
                'Bluetooth Scan',
                _permissionStatus['bluetoothScan'] ?? false,
                Icons.bluetooth_searching,
              ),
              _permissionTile(
                'Bluetooth Advertise',
                _permissionStatus['bluetoothAdvertise'] ?? false,
                Icons.bluetooth,
              ),
              _permissionTile(
                'Bluetooth Connect',
                _permissionStatus['bluetoothConnect'] ?? false,
                Icons.bluetooth_connected,
              ),
              _permissionTile(
                'Location',
                _permissionStatus['location'] ?? false,
                Icons.location_on_outlined,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loadPermissions,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Permissions'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BlueSnapTheme.primary,
                    side: const BorderSide(color: BlueSnapTheme.border),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Service Status ───────────────────
              const Text('Service Status', style: BlueSnapTheme.headingS),
              const SizedBox(height: 16),
              _statusRow('Bluetooth State', _getStateText(bt.state), _getStateColor(bt.state)),
              _statusRow('Discovered Devices', '${bt.deviceCount}', BlueSnapTheme.primary),
              _statusRow('Connected Devices', bt.connectedDeviceId != null ? '1' : '0', BlueSnapTheme.accentGreen),
              const SizedBox(height: 32),

              // ── Info Card ────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: BlueSnapTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(BlueSnapTheme.radiusL),
                  border: Border.all(color: BlueSnapTheme.primary.withValues(alpha: 0.2), width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: BlueSnapTheme.primary, size: 20),
                        const SizedBox(width: 8),
                        const Text('About Real Mode', style: BlueSnapTheme.bodyM),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Real mode uses Google\'s Nearby Connections API to discover other BlueSnap users via Bluetooth and Wi-Fi Direct. '
                      'You need at least 2 physical devices with the app installed to see real discoveries.',
                      style: BlueSnapTheme.bodyS.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _permissionTile(String name, bool granted, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BlueSnapTheme.bgCard,
        borderRadius: BorderRadius.circular(BlueSnapTheme.radiusM),
        border: Border.all(color: BlueSnapTheme.border, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: granted ? BlueSnapTheme.accentGreen : BlueSnapTheme.accentOrange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name, style: BlueSnapTheme.bodyM.copyWith(fontSize: 14)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (granted ? BlueSnapTheme.accentGreen : BlueSnapTheme.accentOrange).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              granted ? 'Granted' : 'Denied',
              style: TextStyle(
                color: granted ? BlueSnapTheme.accentGreen : BlueSnapTheme.accentOrange,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: BlueSnapTheme.bodyM.copyWith(fontSize: 14)),
          ),
          Text(
            value,
            style: BlueSnapTheme.bodyM.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _getStateText(state) {
    return switch (state.toString().split('.').last) {
      'idle' => 'Idle',
      'scanning' => 'Scanning...',
      'advertising' => 'Advertising',
      'connected' => 'Connected',
      'error' => 'Error',
      _ => 'Unknown',
    };
  }

  Color _getStateColor(state) {
    return switch (state.toString().split('.').last) {
      'scanning' => BlueSnapTheme.primary,
      'advertising' => BlueSnapTheme.accentPurple,
      'connected' => BlueSnapTheme.accentGreen,
      'error' => BlueSnapTheme.accentRed,
      _ => BlueSnapTheme.textSecondary,
    };
  }
}
