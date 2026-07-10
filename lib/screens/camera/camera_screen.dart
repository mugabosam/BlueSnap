/// BlueSnap Camera Screen
/// Capture photos and videos to share via Bluetooth.
/// Includes filters, flash, timer, and front/back camera toggle.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme.dart';
import '../../data/models/models.dart';
import '../../data/database/database_service.dart';
import '../../services/bluetooth_service.dart';
import '../../widgets/shared_widgets.dart';
import '../stories/create_story_screen.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with TickerProviderStateMixin {
  final _picker = ImagePicker();
  bool _isRecording = false;
  bool _isFrontCamera = true;
  bool _flashOn = false;
  int _selectedFilter = 0;
  int _timerSeconds = 0;
  String? _capturedPath;
  bool _showPreview = false;
  Timer? _recordTimer;
  int _recordDuration = 0;

  // Live camera
  CameraController? _camController;
  List<CameraDescription> _cameras = const [];
  bool _camReady = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      if (_cameras.isEmpty) _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      final desc = _cameras.firstWhere(
        (c) => _isFrontCamera
            ? c.lensDirection == CameraLensDirection.front
            : c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
      final ctrl = CameraController(
        desc,
        ResolutionPreset.high,
        enableAudio: true,
      );
      await ctrl.initialize();
      await _camController?.dispose();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      setState(() {
        _camController = ctrl;
        _camReady = true;
      });
    } catch (e) {
      debugPrint('[Camera] init failed: $e');
      if (mounted) setState(() => _camReady = false);
    }
  }

  final _filters = [
    {'name': 'None', 'color': Colors.transparent, 'blend': BlendMode.dst},
    {'name': 'Warm', 'color': const Color(0x30FF9500), 'blend': BlendMode.overlay},
    {'name': 'Cool', 'color': const Color(0x300A84FF), 'blend': BlendMode.overlay},
    {'name': 'Vintage', 'color': const Color(0x40FFD700), 'blend': BlendMode.multiply},
    {'name': 'Noir', 'color': const Color(0x60000000), 'blend': BlendMode.saturation},
    {'name': 'Vivid', 'color': const Color(0x20FF0000), 'blend': BlendMode.colorBurn},
    {'name': 'Fade', 'color': const Color(0x30FFFFFF), 'blend': BlendMode.lighten},
  ];

  @override
  void dispose() {
    _recordTimer?.cancel();
    _camController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showPreview && _capturedPath != null) {
      return _buildPreviewScreen();
    }
    return _buildCameraScreen();
  }

  Widget _buildCameraScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Live camera preview (falls back to a hint if unavailable).
          Positioned.fill(
            child: _camReady && _camController != null
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _camController!.value.previewSize?.height ?? 1080,
                      height: _camController!.value.previewSize?.width ?? 1920,
                      child: CameraPreview(_camController!),
                    ),
                  )
                : Container(
                    color: Colors.grey.shade900,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.no_photography_outlined,
                              size: 72, color: Colors.white24),
                          const SizedBox(height: 12),
                          Text('Camera unavailable',
                              style: BlueSnapTheme.bodyM
                                  .copyWith(color: Colors.white38)),
                        ],
                      ),
                    ),
                  ),
          ),

          // Filter overlay
          if (_selectedFilter > 0)
            Positioned.fill(
              child: Container(
                color: (_filters[_selectedFilter]['color'] as Color),
              ),
            ),

          // Recording indicator
          if (_isRecording)
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: BlueSnapTheme.accentRed.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDuration(_recordDuration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          fontFamily: BlueSnapTheme.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Top controls
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _topButton(Icons.close, () => Navigator.of(context).maybePop()),
                    const Spacer(),
                    _topButton(
                      _flashOn ? Icons.flash_on : Icons.flash_off,
                      () => setState(() => _flashOn = !_flashOn),
                    ),
                    const SizedBox(width: 12),
                    _topButton(
                      Icons.timer,
                      () => setState(() {
                        _timerSeconds = _timerSeconds == 0 ? 3 : _timerSeconds == 3 ? 10 : 0;
                      }),
                      badge: _timerSeconds > 0 ? '$_timerSeconds' : null,
                    ),
                    const SizedBox(width: 12),
                    _topButton(
                      Icons.music_note,
                      () {},
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                children: [
                  // Filters row
                  SizedBox(
                    height: 44,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filters.length,
                      itemBuilder: (_, i) {
                        final isSelected = i == _selectedFilter;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedFilter = i),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? BlueSnapTheme.primary.withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: isSelected
                                  ? Border.all(color: BlueSnapTheme.primary, width: 1.5)
                                  : null,
                            ),
                            child: Text(
                              _filters[i]['name'] as String,
                              style: TextStyle(
                                color: isSelected ? BlueSnapTheme.primary : Colors.white70,
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Shutter + controls
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Gallery
                        GestureDetector(
                          onTap: _pickFromGallery,
                          child: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white24, width: 1),
                            ),
                            child: const Icon(Icons.photo_library, color: Colors.white, size: 22),
                          ),
                        ),

                        // Shutter button
                        GestureDetector(
                          onTap: _takePhoto,
                          onLongPressStart: (_) => _startRecording(),
                          onLongPressEnd: (_) => _stopRecording(),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: _isRecording ? 80 : 72,
                            height: _isRecording ? 80 : 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _isRecording ? BlueSnapTheme.accentRed : Colors.white,
                                width: 4,
                              ),
                            ),
                            padding: const EdgeInsets.all(3),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _isRecording ? BlueSnapTheme.accentRed : Colors.white,
                                shape: _isRecording ? BoxShape.rectangle : BoxShape.circle,
                                borderRadius: _isRecording ? BorderRadius.circular(8) : null,
                              ),
                            ),
                          ),
                        ),

                        // Flip camera
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isFrontCamera = !_isFrontCamera;
                              _camReady = false;
                            });
                            _initCamera();
                          },
                          child: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 22),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Mode switcher
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _modeLabel('PHOTO', true),
                      const SizedBox(width: 24),
                      _modeLabel('VIDEO', false),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Preview placeholder
          Positioned.fill(
            child: Container(
              color: Colors.grey.shade900,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.image, size: 80, color: Colors.white24),
                    const SizedBox(height: 16),
                    Text('Photo captured', style: BlueSnapTheme.bodyM.copyWith(color: Colors.white54)),
                  ],
                ),
              ),
            ),
          ),

          // Top bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _topButton(Icons.close, () => setState(() => _showPreview = false)),
                    const Spacer(),
                    _topButton(Icons.text_fields, () {}),
                    const SizedBox(width: 12),
                    _topButton(Icons.edit, () {}),
                    const SizedBox(width: 12),
                    _topButton(Icons.emoji_emotions_outlined, () {}),
                  ],
                ),
              ),
            ),
          ),

          // Bottom send bar
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    // Save button
                    GestureDetector(
                      onTap: () {
                        showAppSnack(context, 'Photo saved',
                            icon: Icons.download_done_rounded);
                      },
                      child: _bottomAction(Icons.download, 'Save'),
                    ),
                    const SizedBox(width: 12),
                    // Story button
                    GestureDetector(
                      onTap: () {
                        setState(() => _showPreview = false);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CreateStoryScreen()),
                        );
                      },
                      child: _bottomAction(Icons.auto_awesome, 'Story'),
                    ),
                    const Spacer(),
                    // Send button
                    GestureDetector(
                      onTap: () => _showSendToPicker(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: BlueSnapTheme.primary,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.bluetooth, color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                            const Text(
                              'Send',
                              style: TextStyle(
                                color: Colors.white, fontSize: 15,
                                fontWeight: FontWeight.w700,
                                fontFamily: BlueSnapTheme.fontFamily,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSendToPicker(BuildContext context) {
    final bt = BluetoothService();
    final devices = bt.discoveredDevices;

    if (devices.isEmpty) {
      showAppSnack(context, 'No nearby devices. Start radar scan first.',
          icon: Icons.radar_rounded, isError: true);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: BlueSnapTheme.bgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: BlueSnapTheme.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Send to', style: BlueSnapTheme.headingS),
              ),
              const Divider(height: 1, color: BlueSnapTheme.divider),
              ...devices.take(6).map((device) {
                return ListTile(
                  leading: UserAvatar(
                    name: device.userName,
                    colorIndex: device.avatarColorIndex,
                    size: 40,
                  ),
                  title: Text(device.userName, style: BlueSnapTheme.bodyM),
                  trailing: const Icon(Icons.send_rounded, color: BlueSnapTheme.primary, size: 20),
                  onTap: () {
                    final db = DatabaseService();
                    final user = db.currentUser;
                    if (user == null) return;

                    final uuid = const Uuid();
                    final convId = 'conv_${device.deviceId}';
                    final msg = Message(
                      id: uuid.v4(),
                      conversationId: convId,
                      senderId: user.id,
                      receiverId: device.deviceId,
                      content: '📷 Photo',
                      messageTypeIndex: MessageType.image.index,
                      statusIndex: MessageStatus.sending.index,
                      mediaPath: _capturedPath,
                    );
                    db.saveMessage(msg);

                    var conv = db.getConversationByPeer(device.deviceId);
                    if (conv == null) {
                      conv = Conversation(
                        id: convId,
                        peerId: device.deviceId,
                        peerName: device.userName,
                        peerAvatarColorIndex: device.avatarColorIndex,
                      );
                      db.saveConversation(conv);
                    }
                    conv.lastMessage = '📷 Photo';
                    conv.lastMessageTime = DateTime.now();
                    conv.save();

                    bt.sendMessage(msg);

                    Navigator.pop(context);
                    setState(() => _showPreview = false);

                    showAppSnack(context, 'Photo sent to ${device.userName}',
                        icon: Icons.bluetooth_rounded);
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _topButton(IconData icon, VoidCallback onTap, {String? badge}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            if (badge != null)
              Positioned(
                right: 4, top: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: BlueSnapTheme.primary, shape: BoxShape.circle),
                  child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bottomAction(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: Colors.white12, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _modeLabel(String text, bool active) {
    return Text(
      text,
      style: TextStyle(
        color: active ? Colors.white : Colors.white38,
        fontSize: 12, fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
  }

  Future<void> _takePhoto() async {
    if (_timerSeconds > 0) {
      await Future.delayed(Duration(seconds: _timerSeconds));
    }

    // Prefer the live controller; fall back to the system camera if it's not up.
    if (_camReady && _camController != null && !_camController!.value.isTakingPicture) {
      try {
        final file = await _camController!.takePicture();
        setState(() { _capturedPath = file.path; _showPreview = true; });
        return;
      } catch (e) {
        debugPrint('[Camera] takePicture failed: $e');
      }
    }

    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: _isFrontCamera ? CameraDevice.front : CameraDevice.rear,
        imageQuality: 85,
      );
      if (photo != null) {
        setState(() { _capturedPath = photo.path; _showPreview = true; });
      }
    } catch (e) {
      if (mounted) {
        showAppSnack(context, "Couldn't capture a photo", isError: true);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final photo = await _picker.pickImage(source: ImageSource.gallery);
      if (photo != null) {
        setState(() { _capturedPath = photo.path; _showPreview = true; });
      }
    } catch (_) {}
  }

  Future<void> _startRecording() async {
    if (!_camReady || _camController == null) return;
    try {
      await _camController!.startVideoRecording();
      setState(() { _isRecording = true; _recordDuration = 0; });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() => _recordDuration++);
        if (_recordDuration >= 60) _stopRecording(); // Max 60s
      });
    } catch (e) {
      debugPrint('[Camera] startVideoRecording failed: $e');
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    if (!_isRecording || _camController == null) return;
    try {
      final file = await _camController!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _capturedPath = file.path;
        _showPreview = true;
      });
    } catch (e) {
      debugPrint('[Camera] stopVideoRecording failed: $e');
      setState(() => _isRecording = false);
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
