/// BlueSnap File Transfer Progress Widget
/// Shows live progress bar during Bluetooth/Wi-Fi Direct transfers
/// with speed estimate and transport type indicator.
library;

import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/models/models.dart';

class FileTransferProgress extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final TransportType transport;
  final String fileName;
  final int fileSizeBytes;
  final VoidCallback? onCancel;

  const FileTransferProgress({
    super.key,
    required this.progress,
    required this.transport,
    required this.fileName,
    required this.fileSizeBytes,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (progress * 100).toInt();
    final transferred = (fileSizeBytes * progress).round();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BlueSnapTheme.bgCard,
        borderRadius: BorderRadius.circular(BlueSnapTheme.radiusM),
        border: Border.all(color: BlueSnapTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _transportIcon,
                size: 16,
                color: _transportColor,
              ),
              const SizedBox(width: 6),
              Text(
                'Sending via ${_transportLabel}',
                style: BlueSnapTheme.caption.copyWith(color: _transportColor),
              ),
              const Spacer(),
              if (onCancel != null)
                GestureDetector(
                  onTap: onCancel,
                  child: const Icon(Icons.close, size: 16, color: BlueSnapTheme.textTertiary),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: BlueSnapTheme.bgElevated,
              valueColor: AlwaysStoppedAnimation(_transportColor),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                fileName.length > 20 ? '${fileName.substring(0, 17)}...' : fileName,
                style: BlueSnapTheme.caption,
              ),
              const Spacer(),
              Text(
                '${_formatSize(transferred)} / ${_formatSize(fileSizeBytes)} ($percentage%)',
                style: BlueSnapTheme.caption.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color get _transportColor => switch (transport) {
    TransportType.ble => BlueSnapTheme.primary,
    TransportType.classic => BlueSnapTheme.accentPurple,
    TransportType.wifiDirect => BlueSnapTheme.accentGreen,
    TransportType.mesh => BlueSnapTheme.accentOrange,
  };

  IconData get _transportIcon => switch (transport) {
    TransportType.ble => Icons.bluetooth,
    TransportType.classic => Icons.bluetooth_connected,
    TransportType.wifiDirect => Icons.wifi,
    TransportType.mesh => Icons.hub,
  };

  String get _transportLabel => switch (transport) {
    TransportType.ble => 'BLE',
    TransportType.classic => 'Bluetooth',
    TransportType.wifiDirect => 'Wi-Fi Direct',
    TransportType.mesh => 'Mesh',
  };

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Snap viewer — tap-and-hold to view, disappears after expiry
class SnapViewer extends StatefulWidget {
  final String? mediaPath;
  final String? textContent;
  final int expirySeconds;
  final VoidCallback onExpired;

  const SnapViewer({
    super.key,
    this.mediaPath,
    this.textContent,
    this.expirySeconds = 10,
    required this.onExpired,
  });

  @override
  State<SnapViewer> createState() => _SnapViewerState();
}

class _SnapViewerState extends State<SnapViewer>
    with SingleTickerProviderStateMixin {
  late AnimationController _timerController;

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.expirySeconds),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onExpired();
        if (mounted) Navigator.of(context).pop();
      }
    });
    _timerController.forward();
  }

  @override
  void dispose() {
    _timerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            // Content
            Positioned.fill(
              child: Container(
                color: Colors.grey.shade900,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.visibility, size: 48, color: Colors.white24),
                      const SizedBox(height: 16),
                      if (widget.textContent != null)
                        Text(
                          widget.textContent!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Snap — tap to close',
                        style: BlueSnapTheme.bodyS.copyWith(color: Colors.white38),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Timer bar
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: AnimatedBuilder(
                    animation: _timerController,
                    builder: (_, __) => LinearProgressIndicator(
                      value: 1.0 - _timerController.value,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation(
                        _timerController.value > 0.7
                            ? BlueSnapTheme.accentRed
                            : BlueSnapTheme.primary,
                      ),
                      minHeight: 3,
                    ),
                  ),
                ),
              ),
            ),

            // Ghost icon
            Positioned(
              bottom: 40, left: 0, right: 0,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_delete, size: 16, color: Colors.white24),
                    const SizedBox(width: 6),
                    AnimatedBuilder(
                      animation: _timerController,
                      builder: (_, __) {
                        final remaining = ((1 - _timerController.value) * widget.expirySeconds).ceil();
                        return Text(
                          '${remaining}s',
                          style: BlueSnapTheme.caption.copyWith(color: Colors.white38),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
