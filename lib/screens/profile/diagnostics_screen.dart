/// Diagnostics Screen - Debug Bluetooth connectivity
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../services/permission_service.dart';
import '../../providers/providers.dart';
import '../../widgets/shared_widgets.dart';

class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  final List<String> _logs = [];
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isChecking = true;
      _logs.clear();
    });

    _addLog('🔍 Starting diagnostics...');
    await Future.delayed(const Duration(milliseconds: 500));

    // Check permissions
    _addLog('\n📋 PERMISSIONS CHECK:');
    final permService = PermissionService();
    final hasPerms = await permService.hasBluetoothPermissions();
    _addLog('All permissions granted: ${hasPerms ? "✅ YES" : "❌ NO"}');

    // Individual permission check
    final status = await permService.checkDetailedPermissions();
    status.forEach((key, value) {
      _addLog('  $key: ${value ? "✅" : "❌"}');
    });

    // Check Bluetooth service
    _addLog('\n📡 TRANSPORT (Nearby Connections):');
    final bt = ref.read(bluetoothProvider);
    _addLog('Is scanning: ${bt.isScanning ? "✅ YES" : "❌ NO"}');
    _addLog('Discovered devices: ${bt.discoveredDevices.length}');
    _addLog('Connected: ${bt.connectedDeviceId != null ? "✅ YES" : "❌ NO"}');

    // Current user
    _addLog('\n👤 USER INFO:');
    final user = ref.read(databaseProvider).currentUser;
    if (user != null) {
      _addLog('Username: "${user.displayName}"');
      _addLog('User ID: ${user.id.substring(0, 8)}...');
    } else {
      _addLog('❌ No user found (complete onboarding!)');
    }

    _addLog('\n💡 RECOMMENDATIONS:');
    
    if (!hasPerms) {
      _addLog('⚠️ Grant ALL permissions:');
      _addLog('   Settings → Apps → BlueSnap → Permissions');
      _addLog('   Location → "Allow all the time"');
    }
    
    if (!bt.isScanning) {
      _addLog('⚠️ Open the Nearby tab to start discovery');
    }

    if (bt.discoveredDevices.isEmpty && bt.isScanning) {
      _addLog('⚠️ No devices found. Ensure:');
      _addLog('   • Other device has BlueSnap installed');
      _addLog('   • Other device is on Search → Nearby');
      _addLog('   • Both devices have Bluetooth + Location ON');
      _addLog('   • Devices are within 10 meters');
      _addLog('   • Different usernames on each device');
    }

    _addLog('\n✅ Diagnostics complete!');
    _addLog('Tap "Copy Logs" to share for debugging');

    setState(() => _isChecking = false);
  }

  void _addLog(String message) {
    if (mounted) {
      setState(() => _logs.add(message));
    }
  }

  void _copyLogs() {
    final logsText = _logs.join('\n');
    Clipboard.setData(ClipboardData(text: logsText));
    showAppSnack(context, 'Logs copied to clipboard',
        icon: Icons.copy_all_rounded);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlueSnapTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: BlueSnapTheme.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: BlueSnapTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Diagnostics', style: BlueSnapTheme.headingL),
        actions: [
          TextButton.icon(
            onPressed: _copyLogs,
            icon: const Icon(Icons.copy, color: BlueSnapTheme.accent, size: 18),
            label: const Text('Copy Logs', style: TextStyle(color: BlueSnapTheme.accent)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BlueSnapTheme.bgSecondary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bug_report, color: BlueSnapTheme.accent, size: 24),
                    SizedBox(width: 8),
                    Text('Bluetooth Diagnostics', style: BlueSnapTheme.headingM),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'This screen helps debug connection issues between devices.',
                  style: BlueSnapTheme.bodyS.copyWith(color: BlueSnapTheme.textSecondary),
                ),
              ],
            ),
          ),

          // Logs
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: BlueSnapTheme.bgSecondary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: _isChecking
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: BlueSnapTheme.accent),
                          SizedBox(height: 16),
                          Text('Running diagnostics...', style: BlueSnapTheme.bodyM),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: SelectableText(
                            log,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: log.startsWith('✅')
                                  ? Colors.green
                                  : log.startsWith('❌')
                                      ? Colors.red
                                      : log.startsWith('⚠️')
                                          ? Colors.orange
                                          : BlueSnapTheme.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isChecking ? null : _runDiagnostics,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Re-run Diagnostics'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BlueSnapTheme.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
