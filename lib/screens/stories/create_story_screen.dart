/// BlueSnap Create Story Screen
/// Create text stories with background colors to share via Bluetooth.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../services/bluetooth_service.dart';
import '../../widgets/shared_widgets.dart';

class CreateStoryScreen extends ConsumerStatefulWidget {
  /// Optional pre-captured photo/video (e.g. from the camera screen).
  final String? initialImagePath;
  const CreateStoryScreen({super.key, this.initialImagePath});

  @override
  ConsumerState<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends ConsumerState<CreateStoryScreen> {
  final _textController = TextEditingController();
  final _uuid = const Uuid();
  final _picker = ImagePicker();
  int _selectedBgIndex = 0;
  bool _isPosting = false;
  late String? _imagePath = widget.initialImagePath;

  static const _backgrounds = [
    [Color(0xFF6C5CE7), Color(0xFF0A84FF)],
    [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
    [Color(0xFF00D2D3), Color(0xFF10AC84)],
    [Color(0xFF5F27CD), Color(0xFFF368E0)],
    [Color(0xFFFF6348), Color(0xFFEE5A24)],
    [Color(0xFF2E86DE), Color(0xFF54A0FF)],
    [Color(0xFF1A1A1E), Color(0xFF38383A)],
    [Color(0xFF0A84FF), Color(0xFF00E5FF)],
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final hasContent = _textController.text.trim().isNotEmpty || _imagePath != null;
    final colors = _backgrounds[_selectedBgIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Story preview
          Positioned.fill(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: TextField(
                      controller: _textController,
                      textAlign: TextAlign.center,
                      maxLines: null,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        fontFamily: BlueSnapTheme.fontFamily,
                        height: 1.3,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Type your story...',
                        hintStyle: TextStyle(
                          color: Colors.white38,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                        border: InputBorder.none,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.black38,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 22),
                      ),
                    ),
                    const Spacer(),
                    // Photo button
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.black38,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.photo, color: Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Camera button
                    GestureDetector(
                      onTap: _takePhoto,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.black38,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 22),
                      ),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Background color picker
                  SizedBox(
                    height: 48,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _backgrounds.length,
                      itemBuilder: (_, i) {
                        final isSelected = i == _selectedBgIndex;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedBgIndex = i),
                          child: Container(
                            width: 36,
                            height: 36,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _backgrounds[i],
                              ),
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 2.5)
                                  : Border.all(color: Colors.white24, width: 1),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white, size: 16)
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Post button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        // User avatar
                        UserAvatar(
                          name: user.displayName,
                          colorIndex: user.avatarColorIndex,
                          size: 40,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Your Story',
                          style: BlueSnapTheme.bodyM.copyWith(color: Colors.white70),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: hasContent && !_isPosting
                              ? () => _createStory(user)
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: hasContent && !_isPosting
                                  ? BlueSnapTheme.primary
                                  : BlueSnapTheme.primary.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: _isPosting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.bluetooth, color: Colors.white, size: 16),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Share Story',
                                        style: TextStyle(
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final photo = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (photo != null) {
        setState(() => _imagePath = photo.path);
      }
    } catch (_) {}
  }

  Future<void> _takePhoto() async {
    try {
      final photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (photo != null) {
        setState(() => _imagePath = photo.path);
      }
    } catch (_) {}
  }

  Future<void> _createStory(User user) async {
    final text = _textController.text.trim();
    if (text.isEmpty && _imagePath == null) return;

    setState(() => _isPosting = true);

    final story = Story(
      id: _uuid.v4(),
      authorId: user.id,
      authorName: user.displayName,
      authorAvatarColorIndex: user.avatarColorIndex,
      textOverlay: text.isNotEmpty ? text : null,
      mediaPath: _imagePath,
    );

    final db = ref.read(databaseProvider);
    await db.saveStory(story);
    ref.read(storiesProvider.notifier).refresh();

    // Propagate the story text to connected peers (media stays local for now).
    if (text.isNotEmpty) {
      await BluetoothService().broadcastFeed({
        'type': 'story',
        'id': story.id,
        'authorId': story.authorId,
        'authorName': story.authorName,
        'color': story.authorAvatarColorIndex,
        'text': text,
        'createdAt': story.createdAt.toIso8601String(),
      });
    }

    if (mounted) {
      Navigator.pop(context);
      showAppSnack(context, 'Story shared to nearby users',
          icon: Icons.bluetooth_rounded);
    }
  }
}
