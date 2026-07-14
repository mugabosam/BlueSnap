/// BlueSnap Create Story — Instagram-style editor: photo/gradient canvas with a
/// creative toolbar (text, emoji, music) instead of a colour-swatch picker.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
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
  bool _showEmoji = false;
  String? _musicPath;
  String? _musicName;
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

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ── Canvas: photo background, or a tap-to-cycle gradient ──
          Positioned.fill(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: _imagePath != null
                  ? MediaImage(path: _imagePath!, fit: BoxFit.cover)
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _backgrounds[_selectedBgIndex],
                        ),
                      ),
                    ),
            ),
          ),

          // Scrim over photos so white text stays legible.
          if (_imagePath != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(color: Colors.black.withValues(alpha: 0.12)),
              ),
            ),

          // ── Centered editable text overlay ──
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: TextField(
                controller: _textController,
                textAlign: TextAlign.center,
                maxLines: null,
                cursorColor: Colors.white,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  fontFamily: BlueSnapTheme.fontFamily,
                  height: 1.3,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 10)],
                ),
                decoration: const InputDecoration(
                  hintText: 'Tap to type',
                  hintStyle: TextStyle(
                    color: Colors.white54,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),

          // ── Top bar: close + optional music chip ──
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    _roundBtn(Icons.close, () => Navigator.pop(context)),
                    const Spacer(),
                    if (_musicName != null) _musicChip(),
                  ],
                ),
              ),
            ),
          ),

          // ── Right-side creative toolbar (Instagram-style) ──
          Positioned(
            top: 0, bottom: 0, right: 8,
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _toolBtn(Iconsax.text, 'Text',
                        () => FocusScope.of(context).requestFocus(FocusNode())),
                    _toolBtn(Iconsax.emoji_happy, 'Emoji',
                        () => setState(() => _showEmoji = !_showEmoji),
                        active: _showEmoji),
                    _toolBtn(Iconsax.music, 'Music', _pickMusic,
                        active: _musicName != null),
                    _toolBtn(Iconsax.gallery, 'Photo', _pickImage),
                    if (_imagePath == null)
                      _toolBtn(Iconsax.colorfilter, 'Style', _cycleBackground),
                    if (_imagePath != null)
                      _toolBtn(Iconsax.trash, 'Remove',
                          () => setState(() => _imagePath = null)),
                  ],
                ),
              ),
            ),
          ),

          // ── Emoji quick-strip ──
          if (_showEmoji)
            Positioned(
              left: 0, right: 0, bottom: 92,
              child: _emojiStrip(),
            ),

          // ── Bottom: author + share ──
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    UserAvatar(
                      name: user.displayName,
                      colorIndex: user.avatarColorIndex,
                      imagePath: user.avatarPath,
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Text('Your story',
                        style: BlueSnapTheme.bodyM.copyWith(color: Colors.white70)),
                    const Spacer(),
                    GestureDetector(
                      onTap: hasContent && !_isPosting ? () => _createStory(user) : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        decoration: BoxDecoration(
                          color: hasContent && !_isPosting
                              ? BlueSnapTheme.primary
                              : Colors.white24,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: _isPosting
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Share',
                                      style: TextStyle(
                                        color: Colors.white, fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: BlueSnapTheme.fontFamily,
                                      )),
                                  SizedBox(width: 6),
                                  Icon(Iconsax.send_1, color: Colors.white, size: 16),
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

  Widget _roundBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40, height: 40,
          decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      );

  Widget _toolBtn(IconData icon, String label, VoidCallback onTap,
      {bool active = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: active ? BlueSnapTheme.primary : Colors.black38,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 3),
            Text(label,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 10,
                    fontFamily: BlueSnapTheme.fontFamily)),
          ],
        ),
      ),
    );
  }

  Widget _musicChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(BlueSnapTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Iconsax.musicnote, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(_musicName!,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12,
                    fontFamily: BlueSnapTheme.fontFamily)),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() { _musicName = null; _musicPath = null; }),
            child: const Icon(Icons.close, color: Colors.white70, size: 14),
          ),
        ],
      ),
    );
  }

  static const _emojis = [
    '😀','😂','🥰','😎','😮','😭','🔥','✨','💜','👍',
    '🎉','🙌','💯','👀','🌟','☀️','🌈','⚡','🎧','📍',
  ];

  Widget _emojiStrip() {
    return Container(
      height: 52,
      color: Colors.black45,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final e in _emojis)
            GestureDetector(
              onTap: () {
                _textController.text = _textController.text + e;
                _textController.selection = TextSelection.collapsed(
                    offset: _textController.text.length);
                setState(() {});
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Center(child: Text(e, style: const TextStyle(fontSize: 26))),
              ),
            ),
        ],
      ),
    );
  }

  void _cycleBackground() {
    setState(() => _selectedBgIndex = (_selectedBgIndex + 1) % _backgrounds.length);
  }

  Future<void> _pickMusic() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    final picked = result?.files.single;
    if (picked?.path == null) return;
    setState(() {
      _musicPath = picked!.path;
      _musicName = picked.name;
    });
  }

  Future<void> _pickImage() async {
    try {
      final photo = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (photo != null) setState(() => _imagePath = photo.path);
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
    // Attach the picked soundtrack (kept in settings, no schema change) so the
    // story viewer can play it back.
    if (_musicPath != null) {
      await db.setSetting('story_music_${story.id}', _musicPath);
    }
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
