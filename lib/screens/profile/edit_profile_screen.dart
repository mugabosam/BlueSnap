/// BlueSnap Edit Profile Screen
/// Edit display name, bio, and avatar color.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../providers/providers.dart';
import '../../services/media_service.dart';
import '../../widgets/shared_widgets.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late int _selectedColorIndex;
  String? _avatarPath;
  final _picker = ImagePicker();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _selectedColorIndex = user?.avatarColorIndex ?? 0;
    _avatarPath = user?.avatarPath;
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final picked =
          await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 800);
      if (picked == null) return;
      final path = await MediaService().persistAvatar(picked.path);
      setState(() => _avatarPath = path);
    } catch (_) {}
  }

  void _showAvatarSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: BlueSnapTheme.bgCard,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose photo', style: BlueSnapTheme.bodyM),
              onTap: () { Navigator.pop(context); _pickAvatar(ImageSource.gallery); },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take photo', style: BlueSnapTheme.bodyM),
              onTap: () { Navigator.pop(context); _pickAvatar(ImageSource.camera); },
            ),
            if (_avatarPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: BlueSnapTheme.accentRed),
                title: const Text('Remove photo',
                    style: TextStyle(color: BlueSnapTheme.accentRed)),
                onTap: () { Navigator.pop(context); setState(() => _avatarPath = null); },
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  ),
                  const Expanded(
                    child: Text(
                      'Edit Profile',
                      style: BlueSnapTheme.headingS,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  GestureDetector(
                    onTap: _isSaving ? null : _saveProfile,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: BlueSnapTheme.primary,
                        borderRadius: BorderRadius.circular(BlueSnapTheme.radiusFull),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Save',
                              style: TextStyle(
                                color: Colors.white, fontSize: 14,
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

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar preview + change photo
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _showAvatarSourceSheet,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                UserAvatar(
                                  name: _nameController.text.isEmpty ? 'U' : _nameController.text,
                                  colorIndex: _selectedColorIndex,
                                  imagePath: _avatarPath,
                                  size: 96,
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: BlueSnapTheme.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: BlueSnapTheme.bgPrimary, width: 2),
                                    ),
                                    child: const Icon(Icons.camera_alt,
                                        color: Colors.white, size: 15),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _showAvatarSourceSheet,
                            child: Text('Change photo',
                                style: BlueSnapTheme.caption
                                    .copyWith(color: BlueSnapTheme.primary)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Colour (used when there's no photo)
                    if (_avatarPath == null)
                      Center(
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: List.generate(AvatarColors.palette.length, (i) {
                            final isSelected = i == _selectedColorIndex;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedColorIndex = i),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AvatarColors.palette[i],
                                  shape: BoxShape.circle,
                                  border: isSelected
                                      ? Border.all(color: Colors.white, width: 3)
                                      : null,
                                  boxShadow: isSelected
                                      ? [BoxShadow(color: AvatarColors.palette[i].withValues(alpha: 0.5), blurRadius: 8)]
                                      : null,
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                                    : null,
                              ),
                            );
                          }),
                        ),
                      ),
                    const SizedBox(height: 32),

                    // Display name
                    Text('Display Name', style: BlueSnapTheme.headingS.copyWith(fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: BlueSnapTheme.bgCard,
                        borderRadius: BorderRadius.circular(BlueSnapTheme.radiusM),
                        border: Border.all(color: BlueSnapTheme.border, width: 0.5),
                      ),
                      child: TextField(
                        controller: _nameController,
                        style: BlueSnapTheme.bodyM,
                        decoration: InputDecoration(
                          hintText: 'Your display name',
                          hintStyle: BlueSnapTheme.bodyM.copyWith(color: BlueSnapTheme.textTertiary),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Bio
                    Text('Bio', style: BlueSnapTheme.headingS.copyWith(fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: BlueSnapTheme.bgCard,
                        borderRadius: BorderRadius.circular(BlueSnapTheme.radiusM),
                        border: Border.all(color: BlueSnapTheme.border, width: 0.5),
                      ),
                      child: TextField(
                        controller: _bioController,
                        style: BlueSnapTheme.bodyM,
                        maxLines: 3,
                        maxLength: 150,
                        decoration: InputDecoration(
                          hintText: 'Tell people about yourself...',
                          hintStyle: BlueSnapTheme.bodyM.copyWith(color: BlueSnapTheme.textTertiary),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          counterStyle: BlueSnapTheme.caption,
                        ),
                      ),
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

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showAppSnack(context, 'Name cannot be empty',
          icon: Icons.error_outline_rounded, isError: true);
      return;
    }

    setState(() => _isSaving = true);

    final user = ref.read(currentUserProvider);
    if (user != null) {
      user.displayName = name;
      user.bio = _bioController.text.trim().isEmpty ? null : _bioController.text.trim();
      user.avatarColorIndex = _selectedColorIndex;
      user.avatarPath = _avatarPath;
      await user.save();

      // Force watchers to rebuild. Re-assigning the same object instance is a
      // no-op for a StateProvider, so invalidate to re-read the saved user.
      ref.invalidate(currentUserProvider);
    }

    if (mounted) {
      Navigator.of(context).pop();
      showAppSnack(context, 'Profile updated',
          icon: Icons.check_circle_outline_rounded);
    }
  }
}
