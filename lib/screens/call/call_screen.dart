/// BlueSnap Call Screen
/// Audio and video calls using WebRTC for real media streaming.
/// Call signaling travels over Bluetooth, media via local WebRTC.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../widgets/shared_widgets.dart';
import '../../services/bluetooth_service.dart';

enum CallType { audio, video }
enum CallState { ringing, connecting, active, ended }

class CallScreen extends StatefulWidget {
  final String peerName;
  final int peerColorIndex;
  final CallType callType;
  final bool isIncoming;
  final String? peerId;

  const CallScreen({
    super.key,
    required this.peerName,
    required this.peerColorIndex,
    this.callType = CallType.audio,
    this.isIncoming = false,
    this.peerId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen>
    with TickerProviderStateMixin {
  CallState _callState = CallState.connecting;
  late CallType _callType;
  int _callDuration = 0;
  Timer? _timer;
  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _isVideoEnabled = true;
  bool _isFrontCamera = true;

  late AnimationController _pulseController;
  late AnimationController _connectingController;
  StreamSubscription? _callSignalSubscription;
  StreamSubscription? _webrtcSubscription;
  final _bt = BluetoothService();

  // WebRTC
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  RTCPeerConnection? _pc;
  bool _mediaInitialized = false;
  bool _hasRemote = false;
  final List<RTCIceCandidate> _pendingRemoteCandidates = [];
  bool _remoteDescriptionSet = false;

  @override
  void initState() {
    super.initState();
    _callType = widget.callType;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _connectingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _initRenderers();

    // Listen for call signals from peer
    _callSignalSubscription = _bt.onCallSignalReceived.listen((signal) {
      final type = signal['type'] as String?;
      if (type == 'call_accept') {
        if (mounted) {
          setState(() => _callState = CallState.active);
          _startTimer();
          // Caller sets up the peer connection and makes the WebRTC offer.
          _startWebrtc(asCaller: true);
        }
      } else if (type == 'call_reject' || type == 'call_end') {
        _endCall();
      }
    });

    // WebRTC signaling (offer / answer / ICE) relayed over Nearby.
    _webrtcSubscription = _bt.onWebrtcSignal.listen(_onWebrtcSignal);

    if (widget.isIncoming) {
      _callState = CallState.ringing;
    } else {
      // Send the real call request. We stay in "Calling…" until the peer's
      // accept signal actually arrives (handled by the listener above) — no
      // fabricated auto-connect.
      _callState = CallState.connecting;
      if (widget.peerId != null) {
        _bt.sendCallSignal(
          peerId: widget.peerId!,
          signalType: 'call_request',
          callType: _callType == CallType.video ? 'video' : 'audio',
        );
      }
    }
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _initMedia() async {
    if (_mediaInitialized) return;
    try {
      final mediaConstraints = <String, dynamic>{
        'audio': true,
        'video': _callType == CallType.video
            ? {
                'facingMode': _isFrontCamera ? 'user' : 'environment',
                'width': 640,
                'height': 480,
              }
            : false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

      if (_callType == CallType.video) {
        _localRenderer.srcObject = _localStream;
      }

      _mediaInitialized = true;
      if (mounted) setState(() {});
      debugPrint('[Call] Local media ready: audio=${_localStream?.getAudioTracks().length}, video=${_localStream?.getVideoTracks().length}');
    } catch (e) {
      debugPrint('[Call] Failed to initialize media: $e');
    }
  }

  // ── WebRTC ───────────────────────────────────────────
  /// Build the peer connection, publish local tracks, and — if we're the
  /// caller — create and send the offer. Media flows peer-to-peer; only the
  /// tiny SDP/ICE control messages are relayed over Nearby.
  Future<void> _startWebrtc({required bool asCaller}) async {
    if (widget.peerId == null) return;
    await _initMedia();
    if (_pc != null) return;

    // No STUN/TURN: on a local link (Nearby upgrades to Wi-Fi) host/mDNS
    // candidates connect directly, which keeps the zero-internet promise.
    _pc = await createPeerConnection({'iceServers': []});

    for (final track in _localStream?.getTracks() ?? const []) {
      await _pc!.addTrack(track, _localStream!);
    }

    _pc!.onIceCandidate = (c) {
      _bt.sendWebrtc(widget.peerId!, {
        'kind': 'ice',
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      });
    };

    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams.first;
        if (mounted) setState(() => _hasRemote = true);
      }
    };

    if (asCaller) {
      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);
      _bt.sendWebrtc(widget.peerId!, {
        'kind': 'offer',
        'sdp': offer.sdp,
        'sdpType': offer.type,
      });
    }
  }

  Future<void> _onWebrtcSignal(Map<String, dynamic> sig) async {
    if (sig['peerId'] != widget.peerId) return;
    final kind = sig['kind'] as String?;
    try {
      if (kind == 'offer') {
        // Callee side: make sure our connection exists, then answer.
        await _startWebrtc(asCaller: false);
        await _pc!.setRemoteDescription(
            RTCSessionDescription(sig['sdp'] as String?, sig['sdpType'] as String?));
        _remoteDescriptionSet = true;
        await _drainCandidates();
        final answer = await _pc!.createAnswer();
        await _pc!.setLocalDescription(answer);
        _bt.sendWebrtc(widget.peerId!, {
          'kind': 'answer',
          'sdp': answer.sdp,
          'sdpType': answer.type,
        });
      } else if (kind == 'answer') {
        await _pc?.setRemoteDescription(
            RTCSessionDescription(sig['sdp'] as String?, sig['sdpType'] as String?));
        _remoteDescriptionSet = true;
        await _drainCandidates();
      } else if (kind == 'ice') {
        final cand = RTCIceCandidate(
          sig['candidate'] as String?,
          sig['sdpMid'] as String?,
          (sig['sdpMLineIndex'] as num?)?.toInt(),
        );
        if (_remoteDescriptionSet) {
          await _pc?.addCandidate(cand);
        } else {
          _pendingRemoteCandidates.add(cand); // queue until remote SDP is set
        }
      }
    } catch (e) {
      debugPrint('[Call] WebRTC signal error: $e');
    }
  }

  Future<void> _drainCandidates() async {
    for (final c in _pendingRemoteCandidates) {
      await _pc?.addCandidate(c);
    }
    _pendingRemoteCandidates.clear();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _connectingController.dispose();
    _callSignalSubscription?.cancel();
    _webrtcSubscription?.cancel();
    _disposeMedia();
    super.dispose();
  }

  Future<void> _disposeMedia() async {
    _localStream?.getTracks().forEach((track) => track.stop());
    await _localStream?.dispose();
    await _pc?.close();
    _pc = null;
    await _localRenderer.dispose();
    await _remoteRenderer.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _callDuration++);
    });
  }

  void _endCall() {
    _timer?.cancel();
    _localStream?.getTracks().forEach((track) => track.stop());

    if (widget.peerId != null) {
      _bt.sendCallSignal(
        peerId: widget.peerId!,
        signalType: 'call_end',
        callType: _callType == CallType.video ? 'video' : 'audio',
      );
    }
    setState(() => _callState = CallState.ended);
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _acceptCall() {
    if (widget.peerId != null) {
      _bt.sendCallSignal(
        peerId: widget.peerId!,
        signalType: 'call_accept',
        callType: _callType == CallType.video ? 'video' : 'audio',
      );
    }
    setState(() => _callState = CallState.active);
    _startTimer();
    // Callee: prepare the peer connection so we're ready for the caller's offer.
    _startWebrtc(asCaller: false);
  }

  void _rejectCall() {
    if (widget.peerId != null) {
      _bt.sendCallSignal(
        peerId: widget.peerId!,
        signalType: 'call_reject',
        callType: _callType == CallType.video ? 'video' : 'audio',
      );
    }
    setState(() => _callState = CallState.ended);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !_isMuted;
    });
  }

  void _toggleSpeaker() {
    setState(() => _isSpeaker = !_isSpeaker);
    _localStream?.getAudioTracks().forEach((track) {
      track.enableSpeakerphone(_isSpeaker);
    });
  }

  void _toggleVideo() {
    setState(() => _isVideoEnabled = !_isVideoEnabled);
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = _isVideoEnabled;
    });
  }

  Future<void> _switchCamera() async {
    setState(() => _isFrontCamera = !_isFrontCamera);
    final videoTracks = _localStream?.getVideoTracks();
    if (videoTracks != null && videoTracks.isNotEmpty) {
      await Helper.switchCamera(videoTracks.first);
    }
  }

  Future<void> _upgradeToVideo() async {
    setState(() => _callType = CallType.video);
    if (_localStream != null) {
      // Add video track
      try {
        final videoStream = await navigator.mediaDevices.getUserMedia({
          'video': {
            'facingMode': _isFrontCamera ? 'user' : 'environment',
            'width': 640,
            'height': 480,
          },
        });
        final videoTrack = videoStream.getVideoTracks().first;
        _localStream!.addTrack(videoTrack);
        _localRenderer.srcObject = _localStream;
        if (mounted) setState(() {});
      } catch (e) {
        debugPrint('[Call] Failed to add video: $e');
      }
    } else {
      _initMedia();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.5,
                  colors: [
                    AvatarColors.fromIndex(widget.peerColorIndex).withValues(alpha: 0.15),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),

          // Remote video feed (full screen) — real peer video once connected.
          if (_callType == CallType.video && _callState == CallState.active)
            Positioned.fill(
              child: _hasRemote
                  ? RTCVideoView(
                      _remoteRenderer,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  : Container(
                      color: Colors.grey.shade900.withValues(alpha: 0.5),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person, size: 80, color: Colors.white12),
                            const SizedBox(height: 8),
                            Text(widget.peerName,
                                style: const TextStyle(
                                    color: Colors.white24, fontSize: 16)),
                            const SizedBox(height: 4),
                            const Text('Connecting video…',
                                style: TextStyle(color: Colors.white12, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
            ),

          // Self-view PiP (video call) — REAL camera preview
          if (_callType == CallType.video && _callState == CallState.active && _isVideoEnabled)
            Positioned(
              top: 60,
              right: 16,
              child: GestureDetector(
                onTap: _switchCamera,
                child: Container(
                  width: 110,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: BlueSnapTheme.primary.withValues(alpha: 0.5), width: 1.5),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: _mediaInitialized && _localRenderer.srcObject != null
                      ? RTCVideoView(
                          _localRenderer,
                          mirror: _isFrontCamera,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        )
                      : const Center(
                          child: Icon(Icons.person, color: Colors.white24, size: 32),
                        ),
                ),
              ),
            ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 1),

                // Connection info
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: BlueSnapTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 12, color: BlueSnapTheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        _callState == CallState.active
                            ? 'Connected${_mediaInitialized ? ' • Live audio' : ''}'
                            : 'Connecting',
                        style: const TextStyle(
                          color: BlueSnapTheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Avatar (audio call or not active)
                if (_callType == CallType.audio || _callState != CallState.active)
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_callState == CallState.connecting || _callState == CallState.ringing)
                        PulseAnimation(
                          size: 160,
                          color: AvatarColors.fromIndex(widget.peerColorIndex),
                        ),
                      UserAvatar(
                        name: widget.peerName,
                        colorIndex: widget.peerColorIndex,
                        size: 100,
                      ),
                    ],
                  ),

                const SizedBox(height: 20),

                // Name
                Text(widget.peerName, style: BlueSnapTheme.headingL),
                const SizedBox(height: 8),

                // Status / Timer
                AnimatedBuilder(
                  animation: _connectingController,
                  builder: (_, __) {
                    final text = switch (_callState) {
                      CallState.ringing => 'Incoming ${_callType == CallType.video ? 'video' : 'audio'} call...',
                      CallState.connecting => 'Connecting...',
                      CallState.active => _formatDuration(_callDuration),
                      CallState.ended => 'Call ended',
                    };
                    return Text(
                      text,
                      style: BlueSnapTheme.bodyM.copyWith(
                        color: _callState == CallState.active
                            ? BlueSnapTheme.accentGreen
                            : BlueSnapTheme.textSecondary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    );
                  },
                ),

                const Spacer(flex: 2),

                // Controls
                if (_callState == CallState.ringing)
                  _buildIncomingControls()
                else if (_callState != CallState.ended)
                  _buildActiveControls(),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _callButton(
            icon: Icons.call_end,
            color: BlueSnapTheme.accentRed,
            label: 'Decline',
            onTap: _rejectCall,
          ),
          _callButton(
            icon: _callType == CallType.video ? Icons.videocam : Icons.call,
            color: BlueSnapTheme.accentGreen,
            label: 'Accept',
            onTap: _acceptCall,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _controlButton(
                icon: _isMuted ? Icons.mic_off : Icons.mic,
                label: _isMuted ? 'Unmute' : 'Mute',
                active: _isMuted,
                onTap: _toggleMute,
              ),
              if (_callType == CallType.video) ...[
                _controlButton(
                  icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                  label: _isVideoEnabled ? 'Camera On' : 'Camera Off',
                  active: !_isVideoEnabled,
                  onTap: _toggleVideo,
                ),
                _controlButton(
                  icon: Icons.flip_camera_ios,
                  label: 'Flip',
                  onTap: _switchCamera,
                ),
              ],
              _controlButton(
                icon: _isSpeaker ? Icons.volume_up : Icons.volume_down,
                label: _isSpeaker ? 'Speaker' : 'Earpiece',
                active: _isSpeaker,
                onTap: _toggleSpeaker,
              ),
              if (_callType == CallType.audio)
                _controlButton(
                  icon: Icons.videocam,
                  label: 'Video',
                  onTap: _upgradeToVideo,
                ),
            ],
          ),
          const SizedBox(height: 32),
          // End call
          GestureDetector(
            onTap: _endCall,
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: BlueSnapTheme.accentRed,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.call_end, color: Colors.white, size: 30),
            ),
          ),
        ],
      ),
    );
  }

  Widget _callButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    bool active = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: active ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
