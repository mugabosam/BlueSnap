/// BlueSnap Create Post Screen
/// Compose text posts (with optional image) and share to nearby feed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../services/bluetooth_service.dart';
import '../../widgets/shared_widgets.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  /// When resuming a saved draft, its stored fields; posting or re-saving
  /// replaces it, and posting removes it from drafts.
  final Map<String, dynamic>? draft;
  const CreatePostScreen({super.key, this.draft});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  late final TextEditingController _textController =
      TextEditingController(text: widget.draft?['text'] as String? ?? '');
  final _picker = ImagePicker();
  final _uuid = const Uuid();
  late String? _selectedImagePath = widget.draft?['mediaPath'] as String?;
  late final String _draftId =
      widget.draft?['id'] as String? ?? _uuid.v4();
  bool _isPosting = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  bool get _hasContent =>
      _textController.text.trim().isNotEmpty || _selectedImagePath != null;

  /// Closing with unposted content → offer to keep it as a draft.
  Future<void> _onClose() async {
    if (!_hasContent) {
      Navigator.of(context).pop();
      return;
    }
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: BlueSnapTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.drafts_outlined, color: BlueSnapTheme.primary),
              title: const Text('Save as draft', style: BlueSnapTheme.username),
              subtitle: const Text('Finish it later from your profile',
                  style: BlueSnapTheme.bodyS),
              onTap: () => Navigator.pop(context, 'save'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: BlueSnapTheme.accentRed),
              title: const Text('Discard',
                  style: TextStyle(color: BlueSnapTheme.accentRed,
                      fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(context, 'discard'),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Keep editing', style: BlueSnapTheme.username),
              onTap: () => Navigator.pop(context, 'stay'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || choice == 'stay' || choice == null) return;
    if (choice == 'save') {
      await ref.read(databaseProvider).saveDraft({
        'id': _draftId,
        'text': _textController.text.trim(),
        'mediaPath': _selectedImagePath,
        'createdAt': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        Navigator.of(context).pop();
        showAppSnack(context, 'Saved to drafts', icon: Icons.drafts_outlined);
      }
    } else {
      // Discard: if this was a resumed draft, remove the stored copy too.
      await ref.read(databaseProvider).deleteDraft(_draftId);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final hasContent = _textController.text.trim().isNotEmpty || _selectedImagePath != null;

    return Scaffold(
      backgroundColor: BlueSnapTheme.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _onClose,
                    icon: const Icon(Icons.close, size: 24),
                  ),
                  const Expanded(
                    child: Text(
                      'Create Post',
                      style: BlueSnapTheme.headingS,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Post button
                  GestureDetector(
                    onTap: hasContent && !_isPosting ? () => _createPost(user) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: hasContent && !_isPosting
                            ? BlueSnapTheme.primary
                            : BlueSnapTheme.primary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(BlueSnapTheme.radiusFull),
                      ),
                      child: _isPosting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Post',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                fontFamily: BlueSnapTheme.fontFamily,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: BlueSnapTheme.divider),

            // Author info
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  UserAvatar(
                    name: user.displayName,
                    colorIndex: user.avatarColorIndex,
                    size: 44,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.displayName, style: BlueSnapTheme.username.copyWith(fontSize: 15)),
                      Row(
                        children: [
                          const Icon(Icons.public, size: 12, color: BlueSnapTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            'Sharing to people nearby',
                            style: BlueSnapTheme.caption.copyWith(color: BlueSnapTheme.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Text input
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: BlueSnapTheme.bodyM.copyWith(fontSize: 17),
                  decoration: InputDecoration(
                    hintText: "What's on your mind?",
                    hintStyle: BlueSnapTheme.bodyM.copyWith(
                      color: BlueSnapTheme.textTertiary,
                      fontSize: 17,
                    ),
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),

            // Selected image preview
            if (_selectedImagePath != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: BlueSnapTheme.bgCard,
                  borderRadius: BorderRadius.circular(BlueSnapTheme.radiusM),
                  border: Border.all(color: BlueSnapTheme.border, width: 0.5),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.image, size: 48, color: BlueSnapTheme.primary.withValues(alpha: 0.3)),
                          const SizedBox(height: 8),
                          Text('Photo attached', style: BlueSnapTheme.bodyS),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedImagePath = null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Bottom toolbar
            Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              decoration: const BoxDecoration(
                color: BlueSnapTheme.bgSecondary,
                border: Border(
                  top: BorderSide(color: BlueSnapTheme.divider, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  _toolbarButton(Icons.photo_outlined, 'Photo', BlueSnapTheme.accentGreen, _pickImage),
                  _toolbarButton(Icons.camera_alt_outlined, 'Camera', BlueSnapTheme.primary, _takePhoto),
                  _toolbarButton(Icons.location_on_outlined, 'Location', BlueSnapTheme.accentRed, () {}),
                  _toolbarButton(Icons.tag, 'Tag', BlueSnapTheme.accentOrange, () {}),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbarButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: BlueSnapTheme.bodyS.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final photo = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 1080);
      if (photo != null) {
        setState(() => _selectedImagePath = photo.path);
      }
    } catch (_) {}
  }

  Future<void> _takePhoto() async {
    try {
      final photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (photo != null) {
        setState(() => _selectedImagePath = photo.path);
      }
    } catch (_) {}
  }

  Future<void> _createPost(User user) async {
    final text = _textController.text.trim();
    if (text.isEmpty && _selectedImagePath == null) return;

    setState(() => _isPosting = true);

    final post = Post(
      id: _uuid.v4(),
      authorId: user.id,
      authorName: user.displayName,
      authorAvatarColorIndex: user.avatarColorIndex,
      textContent: text.isNotEmpty ? text : null,
      mediaPath: _selectedImagePath,
      distanceMeters: 0,
    );

    // Save to local database; a resumed draft is now posted, so remove it.
    final db = ref.read(databaseProvider);
    await db.savePost(post);
    await db.deleteDraft(_draftId);
    ref.read(postsProvider.notifier).refresh();

    // Propagate the post to everyone currently connected. Text propagates over
    // the wire; media stays local (too large to fan out to the feed for now).
    if (text.isNotEmpty) {
      await BluetoothService().broadcastFeed({
        'type': 'post',
        'id': post.id,
        'authorId': post.authorId,
        'authorName': post.authorName,
        'color': post.authorAvatarColorIndex,
        'text': text,
        'createdAt': post.createdAt.toIso8601String(),
      });
    }

    if (mounted) {
      Navigator.of(context).pop();
      showAppSnack(context, 'Post shared',
          icon: Icons.check_circle_outline_rounded);
    }
  }
}
