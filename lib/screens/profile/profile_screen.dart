/// BlueSnap Profile Screen
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme.dart';
import '../../core/app_icons.dart';
import '../../core/constants.dart';
import '../../data/models/models.dart';
import '../../data/database/database_service.dart';
import '../../providers/providers.dart';
import '../../widgets/shared_widgets.dart';
import '../home/create_post_screen.dart';
import '../home/post_detail_screen.dart';
import '../stories/create_story_screen.dart';
import 'bluetooth_settings_screen.dart';
import 'diagnostics_screen.dart';
import 'edit_profile_screen.dart';

/// Profile tabs: your posts, what you've shared to nearby people, and drafts.
enum _ProfileTab { posts, shared, drafts }

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  _ProfileTab _tab = _ProfileTab.posts;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final posts = ref.watch(postsProvider);
    final myPosts = posts.where((p) => p.authorId == user.id).toList();
    final handle = user.username?.isNotEmpty == true
        ? user.username!
        : user.displayName.toLowerCase().replaceAll(' ', '_');

    return Scaffold(
      backgroundColor: BlueSnapTheme.bgPrimary,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _header(context, handle)),
            SliverToBoxAdapter(
              child: _topSection(context, user, myPosts.length),
            ),
            SliverToBoxAdapter(child: _highlights(context)),
            SliverToBoxAdapter(child: _tabBar()),
            switch (_tab) {
              _ProfileTab.posts => _postGrid(myPosts, user),
              _ProfileTab.shared =>
                _postGrid(DatabaseService().sharedPosts, user, shared: true),
              _ProfileTab.drafts => _draftList(context),
            },
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  // ══ Header ══════════════════════════════════════════════
  Widget _header(BuildContext context, String handle) {
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, size: 14, color: BlueSnapTheme.textPrimary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                handle,
                style: const TextStyle(
                  fontFamily: BlueSnapTheme.fontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: BlueSnapTheme.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: BlueSnapTheme.textPrimary),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CreatePostScreen())),
              behavior: HitTestBehavior.opaque,
              child: const Icon(AppIcons.create,
                  size: 24, color: BlueSnapTheme.textPrimary),
            ),
            const SizedBox(width: 18),
            GestureDetector(
              onTap: () => _showMenu(context),
              behavior: HitTestBehavior.opaque,
              child: const Icon(AppIcons.menu,
                  size: 24, color: BlueSnapTheme.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  // ══ Top: avatar + stats + bio + buttons ════════════════
  Widget _topSection(BuildContext context, User user, int postCount) {
    final db = DatabaseService();
    // Real local stats — no server-backed social graph to fake.
    final connections = db.totalConnections;
    final sent = db.totalMessagesSent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                name: user.displayName,
                colorIndex: user.avatarColorIndex,
                imagePath: user.avatarPath,
                size: 80,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat('$postCount', 'Posts'),
                    _stat(_fmt(connections), 'Chats'),
                    _stat(_fmt(sent), 'Sent'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(user.displayName, style: BlueSnapTheme.username),
          if (user.bio?.isNotEmpty == true) ...[
            const SizedBox(height: 2),
            Text(user.bio!, style: BlueSnapTheme.bodyS),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PillButton(
                  label: 'Edit profile',
                  primary: false,
                  height: 34,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PillButton(
                  label: 'Share profile',
                  primary: false,
                  height: 34,
                  // Real system share sheet — user picks WhatsApp, SMS, etc.
                  onTap: () => Share.share(
                    'I\'m "${user.displayName}" on BlueSnap — the app that '
                    'connects people nearby with zero internet. Install it '
                    'and find me when we\'re in the same place!',
                    subject: 'Find me on BlueSnap',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Invite friends — also via the system share sheet.
              GestureDetector(
                onTap: () => Share.share(
                  'Try BlueSnap: chat, share photos and stories with people '
                  'around you — no internet, no data. Get it and find me nearby!',
                  subject: 'Join me on BlueSnap',
                ),
                child: _squareButton(AppIcons.addUser),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: BlueSnapTheme.fontFamily,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: BlueSnapTheme.textPrimary,
            fontFeatures: BlueSnapTheme.tabular,
          ),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: BlueSnapTheme.caption
                .copyWith(color: BlueSnapTheme.textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _squareButton(IconData icon) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: BlueSnapTheme.surface2,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: BlueSnapTheme.textPrimary),
    );
  }

  // ══ Story shortcut (real — creates a story; no fake highlights) ══
  Widget _highlights(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        height: 86,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CreateStoryScreen())),
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: BlueSnapTheme.surface1,
                      border: Border.all(color: BlueSnapTheme.divider, width: 1),
                    ),
                    child: const Icon(Icons.add,
                        size: 22, color: BlueSnapTheme.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Text('New story',
                      style: BlueSnapTheme.caption.copyWith(
                          color: BlueSnapTheme.textSecondary, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══ Tabs (real: posts / shared / drafts) ═════════════════
  Widget _tabBar() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: BlueSnapTheme.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          _tabItem(AppIcons.grid, _ProfileTab.posts),
          _tabItem(AppIcons.share, _ProfileTab.shared),
          _tabItem(AppIcons.drafts, _ProfileTab.drafts),
        ],
      ),
    );
  }

  Widget _tabItem(IconData icon, _ProfileTab tab) {
    final active = _tab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = tab),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? BlueSnapTheme.textPrimary : Colors.transparent,
                width: 1,
              ),
            ),
          ),
          child: Icon(
            icon,
            size: 24,
            color: active ? BlueSnapTheme.textPrimary : BlueSnapTheme.textTertiary,
          ),
        ),
      ),
    );
  }

  // ══ Post grid (tappable → full post view) ════════════════
  Widget _postGrid(List<Post> posts, User user, {bool shared = false}) {
    if (posts.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 48),
          child: EmptyState(
            icon: shared ? AppIcons.share : AppIcons.grid,
            title: shared ? 'Nothing shared yet' : 'No posts yet',
            subtitle: shared
                ? 'Posts you share with people nearby will appear here.'
                : 'Posts you share will appear on your grid.',
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.only(top: 1),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 1,
          crossAxisSpacing: 1,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) {
            final post = posts[i];
            final color = AvatarColors.fromIndex(post.authorAvatarColorIndex);
            final Widget tile;
            if (post.mediaPath != null) {
              tile = MediaImage(
                path: post.mediaPath!,
                fit: BoxFit.cover,
                isVideo: post.isVideo,
                fallbackColor: color,
              );
            } else {
              tile = Container(
                color: color.withValues(alpha: 0.12),
                padding: const EdgeInsets.all(8),
                alignment: Alignment.center,
                child: Text(
                  post.textContent ?? '',
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: BlueSnapTheme.caption
                      .copyWith(color: BlueSnapTheme.textPrimary, fontSize: 11),
                ),
              );
            }
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
              ).then((_) {
                // Post may have been deleted or edited — refresh the grid.
                ref.read(postsProvider.notifier).refresh();
                if (mounted) setState(() {});
              }),
              child: tile,
            );
          },
          childCount: posts.length,
        ),
      ),
    );
  }

  // ══ Drafts ═══════════════════════════════════════════════
  Widget _draftList(BuildContext context) {
    final drafts = DatabaseService().drafts;
    if (drafts.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: 48),
          child: EmptyState(
            icon: AppIcons.drafts,
            title: 'No drafts',
            subtitle: 'Close a post before publishing and choose\n'
                '"Save as draft" — it will wait for you here.',
          ),
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, i) {
          final d = drafts[i];
          final text = d['text'] as String? ?? '';
          final mediaPath = d['mediaPath'] as String?;
          final created = DateTime.tryParse(d['createdAt'] as String? ?? '');
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: mediaPath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: MediaImage(path: mediaPath, width: 52, height: 52),
                  )
                : Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: BlueSnapTheme.surface2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.notes_rounded,
                        color: BlueSnapTheme.textSecondary),
                  ),
            title: Text(
              text.isNotEmpty ? text : '(photo draft)',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: BlueSnapTheme.bodyM,
            ),
            subtitle: created != null
                ? Text('Saved ${_timeAgoShort(created)}',
                    style: BlueSnapTheme.caption)
                : null,
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: BlueSnapTheme.textTertiary),
              onPressed: () async {
                await DatabaseService().deleteDraft(d['id'] as String);
                if (mounted) setState(() {});
              },
            ),
            // Resume editing this draft.
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CreatePostScreen(draft: d)),
            ).then((_) {
              ref.read(postsProvider.notifier).refresh();
              if (mounted) setState(() {});
            }),
          );
        },
        childCount: drafts.length,
      ),
    );
  }

  String _timeAgoShort(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ══ Menu (settings / diagnostics behind hamburger) ══════
  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: BlueSnapTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: BlueSnapTheme.surface3,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _menuTile(context, AppIcons.edit, 'Edit profile',
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const EditProfileScreen()))),
            _menuTile(context, AppIcons.settings, 'Settings',
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const BluetoothSettingsScreen()))),
            _menuTile(context, AppIcons.diagnostics, 'Diagnostics',
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const DiagnosticsScreen()))),
            _menuTile(context, AppIcons.info, 'About', () {
              Navigator.pop(context);
              _showAbout(context);
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _menuTile(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: BlueSnapTheme.textPrimary, size: 22),
      title: Text(label, style: BlueSnapTheme.bodyM),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: BlueSnapTheme.bgCard,
        title: const Text('BlueSnap', style: BlueSnapTheme.headingS),
        content: Text(
          'Version 1.0.0\n\nConnect locally. Zero internet.',
          style: BlueSnapTheme.bodyS,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close',
                style: TextStyle(color: BlueSnapTheme.primary)),
          ),
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
