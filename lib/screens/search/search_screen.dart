/// BlueSnap Search / Explore — discovery feed (Nearby = people around you)
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/app_icons.dart';
import '../../core/constants.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/shared_widgets.dart';
import '../home/post_detail_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final void Function(NearbyDevice device) onDeviceTap;
  const SearchScreen({super.key, required this.onDeviceTap});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Begin discovery as soon as this tab exists so people populate on their own.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bluetoothProvider).startScan();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlueSnapTheme.bgPrimary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ──────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text('Explore', style: BlueSnapTheme.headingL),
                ],
              ),
            ),
            // ── Search bar ──────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: BlueSnapTheme.surface2,
                  borderRadius: BorderRadius.circular(BlueSnapTheme.radiusM),
                ),
                child: Row(
                  children: [
                    const Icon(AppIcons.search,
                        size: 18, color: BlueSnapTheme.textTertiary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        style: BlueSnapTheme.bodyL,
                        cursorColor: BlueSnapTheme.primary,
                        onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: 'Search people nearby',
                          hintStyle: BlueSnapTheme.bodyL
                              .copyWith(color: BlueSnapTheme.textTertiary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),

            // ── Body: searching → people; otherwise → explore grid ──
            Expanded(child: _query.isNotEmpty ? _nearbyList() : _explore()),
          ],
        ),
      ),
    );
  }

  /// Explore: public photos + videos shared by people near you. Everything that
  /// propagates to your device is public (private posts stay on the author's
  /// phone), so this grid is exactly the public content around you.
  Widget _explore() {
    final me = ref.watch(currentUserProvider);
    final posts = ref
        .watch(postsProvider)
        .where((p) => p.authorId != me?.id && p.mediaPath != null)
        .toList();

    if (posts.isEmpty) {
      // Still discovering over the air → shimmer skeleton; genuinely nothing
      // around → the empty state. (No internet fetch — this is all local/P2P.)
      return ref.read(bluetoothProvider).isScanning
          ? const SkeletonGrid()
          : const _NearbyEmpty();
    }

    return GridView.builder(
      padding: const EdgeInsets.all(1),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 1.5,
        crossAxisSpacing: 1.5,
      ),
      itemCount: posts.length,
      itemBuilder: (_, i) {
        final post = posts[i];
        return GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => PostDetailScreen(post: post))),
          child: Stack(
            fit: StackFit.expand,
            children: [
              MediaImage(
                path: post.mediaPath!,
                fit: BoxFit.cover,
                isVideo: post.isVideo,
                fallbackColor:
                    AvatarColors.fromIndex(post.authorAvatarColorIndex),
              ),
              if (post.isVideo)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(AppIcons.play, color: Colors.white, size: 18),
                ),
            ],
          ),
        ).animate().fadeIn(duration: 220.ms, delay: (i * 25).ms);
      },
    );
  }

  // ── Nearby: real discovered people ──
  Widget _nearbyList() {
    var devices = ref.watch(nearbyDevicesProvider);
    if (_query.isNotEmpty) {
      devices = devices
          .where((d) => d.userName.toLowerCase().contains(_query))
          .toList();
    }
    if (devices.isEmpty) {
      return const _NearbyEmpty();
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: devices.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text('People around you', style: BlueSnapTheme.username),
          );
        }
        final device = devices[i - 1];
        return _personTile(device)
            .animate()
            .fadeIn(duration: 250.ms, delay: ((i - 1) * 40).ms);
      },
    );
  }

  Widget _personTile(NearbyDevice device) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          UserAvatar(
            name: device.userName,
            colorIndex: device.avatarColorIndex,
            size: 52,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device.userName, style: BlueSnapTheme.username),
                const SizedBox(height: 2),
                Text(
                  device.bio?.isNotEmpty == true
                      ? device.bio!
                      : 'Suggested for you',
                  style: BlueSnapTheme.bodyS,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PillButton(
            label: 'Message',
            primary: true,
            fullWidth: false,
            height: 34,
            onTap: () => widget.onDeviceTap(device),
          ),
        ],
      ),
    );
  }

}

class _NearbyEmpty extends StatelessWidget {
  const _NearbyEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PulseAnimation(size: 120),
                  Icon(AppIcons.people,
                      size: 40, color: BlueSnapTheme.textTertiary),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Looking for people around you',
                style: BlueSnapTheme.headingS, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'People nearby will show up here as they come into range.',
              style: BlueSnapTheme.bodyS,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
