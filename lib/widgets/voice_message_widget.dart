/// BlueSnap Voice Message Widget
/// Record and play voice messages with waveform visualization.
/// Uses the `record` package for real audio recording
/// and `audioplayers` for playback.
library;

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/theme.dart';

/// Voice recording state
enum VoiceState { idle, recording, playing, paused }

/// Voice message recorder widget
class VoiceMessageRecorder extends StatefulWidget {
  final void Function(String path, int durationMs)? onRecordingComplete;
  final VoidCallback? onCancel;

  const VoiceMessageRecorder({
    super.key,
    this.onRecordingComplete,
    this.onCancel,
  });

  @override
  State<VoiceMessageRecorder> createState() => _VoiceMessageRecorderState();
}

class _VoiceMessageRecorderState extends State<VoiceMessageRecorder>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  int _recordDuration = 0;
  Timer? _timer;
  Timer? _amplitudeTimer;
  final List<double> _waveform = [];
  late AnimationController _pulseController;
  // ignore: unused_field  — set for clarity/future UI; recording lifecycle is timer-driven
  bool _isRecording = false;
  String? _recordPath;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amplitudeTimer?.cancel();
    _pulseController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        debugPrint('[VoiceRecorder] No microphone permission');
        widget.onCancel?.call();
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      _recordPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _recordPath!,
      );

      setState(() => _isRecording = true);
      _recordDuration = 0;
      _waveform.clear();

      // Duration timer
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _recordDuration++);
        if (_recordDuration >= 120) _stopRecording(); // Max 2 min
      });

      // Amplitude sampling for waveform
      _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
        try {
          final amp = await _recorder.getAmplitude();
          // amp.current is in dBFS (negative), normalize to 0.0-1.0
          final normalized = ((amp.current + 50) / 50).clamp(0.0, 1.0);
          setState(() {
            _waveform.add(normalized);
            if (_waveform.length > 50) _waveform.removeAt(0);
          });
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('[VoiceRecorder] Failed to start: $e');
      // Fallback to simulated if recorder fails
      _startSimulatedRecording();
    }
  }

  void _startSimulatedRecording() {
    final random = Random();
    setState(() => _isRecording = true);
    _recordDuration = 0;
    _waveform.clear();

    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      setState(() {
        _recordDuration = t.tick * 100 ~/ 1000;
        _waveform.add(0.2 + random.nextDouble() * 0.8);
        if (_waveform.length > 50) _waveform.removeAt(0);
      });
      if (_recordDuration >= 120) _stopRecording();
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    _amplitudeTimer?.cancel();

    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}

    setState(() => _isRecording = false);

    final finalPath = path ?? _recordPath ?? 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    widget.onRecordingComplete?.call(finalPath, _recordDuration * 1000);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        color: BlueSnapTheme.bgSecondary,
        border: Border(
          top: BorderSide(color: BlueSnapTheme.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Cancel button
          GestureDetector(
            onTap: () async {
              _timer?.cancel();
              _amplitudeTimer?.cancel();
              try { await _recorder.stop(); } catch (_) {}
              widget.onCancel?.call();
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: BlueSnapTheme.accentRed.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline, color: BlueSnapTheme.accentRed, size: 20),
            ),
          ),
          const SizedBox(width: 12),

          // Waveform
          Expanded(
            child: SizedBox(
              height: 32,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Recording dot
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, __) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: BlueSnapTheme.accentRed.withValues(alpha: 
                          0.5 + _pulseController.value * 0.5,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // Waveform bars
                  Expanded(
                    child: CustomPaint(
                      size: const Size(double.infinity, 32),
                      painter: _WaveformPainter(
                        waveform: _waveform,
                        color: BlueSnapTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Duration
          Text(
            _formatDuration(_recordDuration),
            style: BlueSnapTheme.bodyS.copyWith(
              color: BlueSnapTheme.accentRed,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),

          const SizedBox(width: 12),

          // Send button
          GestureDetector(
            onTap: _stopRecording,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: BlueSnapTheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

/// Voice message player (in chat bubble)
class VoiceMessagePlayer extends StatefulWidget {
  final int durationMs;
  final bool isMine;
  final String? audioPath;

  const VoiceMessagePlayer({
    super.key,
    required this.durationMs,
    this.isMine = false,
    this.audioPath,
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  double _progress = 0;
  Timer? _progressTimer;
  final _random = Random();
  late final List<double> _waveform;

  @override
  void initState() {
    super.initState();
    _waveform = List.generate(30, (_) => 0.15 + _random.nextDouble() * 0.85);

    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        _progressTimer?.cancel();
        setState(() { _isPlaying = false; _progress = 0; });
      }
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _player.pause();
      _progressTimer?.cancel();
    } else {
      if (widget.audioPath != null && widget.audioPath!.isNotEmpty && !widget.audioPath!.startsWith('voice_')) {
        // Real audio file
        try {
          await _player.play(DeviceFileSource(widget.audioPath!));
          _startProgressTracking();
          return;
        } catch (e) {
          debugPrint('[VoicePlayer] Real playback failed: $e');
        }
      }
      // Simulated playback
      _simulatePlayback();
    }
  }

  void _startProgressTracking() {
    _progressTimer?.cancel();
    final totalMs = widget.durationMs;
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      try {
        final pos = await _player.getCurrentPosition();
        if (pos != null && mounted) {
          setState(() => _progress = pos.inMilliseconds / totalMs);
        }
      } catch (_) {}
    });
  }

  void _simulatePlayback() {
    setState(() { _isPlaying = true; _progress = 0; });
    final totalSteps = (widget.durationMs / 100).round();
    int step = 0;
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      step++;
      if (mounted) {
        setState(() => _progress = step / totalSteps);
      }
      if (step >= totalSteps) {
        t.cancel();
        if (mounted) {
          setState(() { _isPlaying = false; _progress = 0; });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isMine ? Colors.white : BlueSnapTheme.primary;
    final bgColor = widget.isMine
        ? Colors.white.withValues(alpha: 0.15)
        : BlueSnapTheme.primary.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play button
          GestureDetector(
            onTap: _togglePlayback,
            child: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 6),

          // Waveform
          SizedBox(
            width: 120,
            height: 24,
            child: CustomPaint(
              painter: _WaveformPainter(
                waveform: _waveform,
                color: color,
                progress: _progress,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Duration
          Text(
            _formatDuration(_isPlaying
                ? (widget.durationMs * _progress).round()
                : widget.durationMs),
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: BlueSnapTheme.fontFamily,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int ms) {
    final s = ms ~/ 1000;
    return '${(s ~/ 60).toString().padLeft(1, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }
}

/// Waveform painter
class _WaveformPainter extends CustomPainter {
  final List<double> waveform;
  final Color color;
  final double progress;

  _WaveformPainter({
    required this.waveform,
    required this.color,
    this.progress = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty) return;

    final barWidth = size.width / waveform.length - 1;
    final maxHeight = size.height;

    for (int i = 0; i < waveform.length; i++) {
      final x = i * (barWidth + 1);
      final barHeight = waveform[i] * maxHeight;
      final y = (maxHeight - barHeight) / 2;

      final isActive = progress >= (i / waveform.length);
      final paint = Paint()
        ..color = isActive ? color : color.withValues(alpha: 0.3)
        ..strokeCap = StrokeCap.round;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth.clamp(1.5, 3), barHeight.clamp(2, maxHeight)),
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) =>
      old.progress != progress || old.waveform.length != waveform.length;
}
