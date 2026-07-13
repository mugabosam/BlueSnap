/// BlueSnap Onboarding — avatar color step (reached after Sign Up)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../services/crypto_service.dart';
import '../../services/media_service.dart';
import '../../services/bluetooth_service.dart';
import '../../widgets/shared_widgets.dart';
import '../auth/set_pin_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  /// When provided (the Sign Up flow), skip the name step and go straight to
  /// picking an avatar color. When null, the full name + color flow runs.
  final String? presetName;
  final String? presetUsername;

  const OnboardingScreen({
    super.key,
    required this.onComplete,
    this.presetName,
    this.presetUsername,
  });

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.presetName ?? '');
  int _selectedColor = 0;
  String? _avatarPath; // chosen profile photo, if any
  final _picker = ImagePicker();
  late int _page = widget.presetName != null ? 1 : 0; // 0 = name, 1 = avatar
  bool _saving = false;

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final picked =
          await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 800);
      if (picked == null) return;
      // Store permanently so the avatar survives app restarts.
      final path = await MediaService().persistAvatar(picked.path);
      setState(() => _avatarPath = path);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlueSnapTheme.bgPrimary,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _page == 0 ? _buildNameInput() : _buildColorPick(),
      ),
    );
  }

  // ── Page 0: Name (fallback only) ─────────────────────
  Widget _buildNameInput() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 60),
            const Text("What's your name?", style: BlueSnapTheme.headingXL),
            const SizedBox(height: 8),
            Text(
              'This is how nearby people will see you.',
              style: BlueSnapTheme.bodyS
                  .copyWith(color: BlueSnapTheme.textSecondary),
            ),
            const SizedBox(height: 32),
            AppTextField(hint: 'Your name', controller: _nameController),
            const Spacer(),
            PillButton(
              label: 'Continue',
              onTap: () {
                if (_nameController.text.trim().isEmpty) return;
                setState(() => _page = 1);
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Page 1: Profile photo ────────────────────────────
  Widget _buildColorPick() {
    final name = _nameController.text.trim();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 60),
            const Text('Add a profile photo', style: BlueSnapTheme.headingXL),
            const SizedBox(height: 8),
            Text(
              'A photo helps people nearby recognise you.',
              style: BlueSnapTheme.bodyS
                  .copyWith(color: BlueSnapTheme.textSecondary),
            ),
            const SizedBox(height: 40),

            // Big tappable avatar preview (photo, or coloured initials fallback).
            Center(
              child: GestureDetector(
                onTap: () => _pickAvatar(ImageSource.gallery),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    UserAvatar(
                      name: name.isEmpty ? '?' : name,
                      colorIndex: _selectedColor,
                      imagePath: _avatarPath,
                      size: 132,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: BlueSnapTheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: BlueSnapTheme.bgPrimary, width: 3),
                        ),
                        child: const Icon(Icons.camera_alt,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(child: Text(name, style: BlueSnapTheme.headingS)),
            const SizedBox(height: 28),

            // Choose photo / take photo
            Row(
              children: [
                Expanded(
                  child: _choiceButton(
                    icon: Icons.photo_library_outlined,
                    label: 'Choose photo',
                    onTap: () => _pickAvatar(ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _choiceButton(
                    icon: Icons.camera_alt_outlined,
                    label: 'Take photo',
                    onTap: () => _pickAvatar(ImageSource.camera),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),
            // No photo? Pick a colour for the initials fallback instead.
            if (_avatarPath == null) ...[
              Text('Or pick a colour',
                  style: BlueSnapTheme.caption
                      .copyWith(color: BlueSnapTheme.textSecondary)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(AvatarColors.palette.length, (i) {
                  final isSelected = i == _selectedColor;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = i),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AvatarColors.palette[i],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? BlueSnapTheme.textPrimary
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }),
              ),
            ],
            const Spacer(),
            PillButton(
              label: 'Start Snapping',
              loading: _saving,
              onTap: _completeOnboarding,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _choiceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: BlueSnapTheme.surface2,
          borderRadius: BorderRadius.circular(BlueSnapTheme.radiusM),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: BlueSnapTheme.textPrimary),
            const SizedBox(width: 8),
            Text(label,
                style: BlueSnapTheme.bodyM.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Future<void> _completeOnboarding() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);

    // Ensure encryption identity exists, then publish our public key on the profile.
    await CryptoService().init();

    final user = User(
      id: const Uuid().v4(),
      displayName: name,
      username: widget.presetUsername,
      avatarColorIndex: _selectedColor,
      avatarPath: _avatarPath,
      publicKey: CryptoService().myPublicKeyBase64,
      isCurrentUser: true,
    );

    final db = ref.read(databaseProvider);
    await db.saveCurrentUser(user);

    // Now that a profile exists, (re)initialise the transport with the real
    // identity. On a fresh install this is the FIRST time Nearby learns who we
    // are — without it, discovery/messaging would run with an empty user id.
    await BluetoothService().init();

    ref.read(currentUserProvider.notifier).state = user;
    ref.read(conversationsProvider.notifier).refresh();
    ref.read(postsProvider.notifier).refresh();
    ref.read(storiesProvider.notifier).refresh();

    if (!mounted) return;
    // Require an app-lock PIN before the profile can be used. Only after it's
    // set do we clear the auth stack and enter the app.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SetPinScreen(
          onComplete: () {
            Navigator.of(context).popUntil((r) => r.isFirst);
            widget.onComplete();
          },
        ),
      ),
    );
  }
}
