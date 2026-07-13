/// BlueSnap Home Feed
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/app_icons.dart';
import '../../data/models/models.dart';
import '../../data/database/database_service.dart';
import '../../providers/providers.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/comments_sheet.dart';
import '../../core/constants.dart';
import '../../services/bluetooth_service.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';
import '../camera/camera_screen.dart';
import '../stories/story_viewer_screen.dart';

class HomeFeedScreen extends ConsumerWidget {
  /// Switch to the Messages tab (wired from the app shell).
  final VoidCallback? onOpenMessages;
  const HomeFeedScreen({super.key, this.onOpenMessages});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(postsProvider);
    final stories = ref.watch(storiesProvider);
    final bookmarks = ref.watch(bookmarksProvider);
    final me = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: BlueSnapTheme.bgPrimary,
      body: SafeArea(
        bottom: false,
        // Pull-to-refresh — real refresh of feed + stories.
        child: RefreshIndicator(
          color: BlueSnapTheme.primary,
          backgroundColor: BlueSnapTheme.bgSecondary,
          displacement: 28,
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            ref.read(postsProvider.notifier).refresh();
            ref.read(storiesProvider.notifier).refresh();
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _header(context)),
              SliverToBoxAdapter(child: _storiesRow(context, stories, me)),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              posts.isEmpty
                  ? const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: AppIcons.empty,
                        title: 'No posts yet',
                        subtitle: 'Posts from people nearby will show up here.',
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _postCard(context, ref, posts[i], bookmarks)
                            .animate()
                            .fadeIn(duration: 300.ms, delay: (i * 45).ms)
                            .slideY(begin: 0.04, end: 0, curve: Curves.easeOut),
                        childCount: posts.length,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // ══ Header ══════════════════════════════════════════════
  Widget _header(BuildContext context) {
    return Container(
      height: 48,
      color: BlueSnapTheme.bgSecondary,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text('BlueSnap', style: BlueSnapTheme.headingL),
          const Spacer(),
          _headerIcon(
            AppIcons.create,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreatePostScreen()),
            ),
          ),
          const SizedBox(width: 20),
          // Activity → real recent comments on your posts.
          _headerIcon(AppIcons.activity,
              onTap: () => _showActivity(context)),
          const SizedBox(width: 20),
          // DM → jump to the Messages tab.
          _headerIcon(AppIcons.dm, onTap: onOpenMessages),
        ],
      ),
    );
  }

  Widget _headerIcon(IconData icon, {VoidCallback? onTap}) {
    return Pressable(
      onTap: onTap,
      child: Icon(icon, size: 24, color: BlueSnapTheme.textPrimary),
    );
  }

  // ══ Activity sheet — real comments on the user's posts ══
  void _showActivity(BuildContext context) {
    final db = DatabaseService();
    final me = db.currentUser;
    final myPosts = db.allPosts.where((p) => p.authorId == me?.id).toList();
    final activity = <Comment>[];
    for (final p in myPosts) {
      activity.addAll(db.getComments(p.id));
    }
    activity.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    showModalBottomSheet(
      context: context,
      backgroundColor: BlueSnapTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              alignment: Alignment.center,
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: BlueSnapTheme.surface3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Activity', style: BlueSnapTheme.headingS),
            ),
            if (activity.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Text('No activity yet. When people comment on your '
                    'posts, it shows up here.', style: BlueSnapTheme.bodyS),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: activity.length.clamp(0, 30),
                  itemBuilder: (_, i) {
                    final c = activity[i];
                    return ListTile(
                      leading: UserAvatar(
                        name: c.authorName,
                        colorIndex: c.authorAvatarColorIndex,
                        size: 40,
                      ),
                      title: Text.rich(TextSpan(children: [
                        TextSpan(text: c.authorName,
                            style: BlueSnapTheme.username.copyWith(fontSize: 13)),
                        TextSpan(text: '  ${c.content}',
                            style: BlueSnapTheme.bodyM.copyWith(fontSize: 13)),
                      ]), maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text('commented', style: BlueSnapTheme.caption),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ══ Stories ═════════════════════════════════════════════
  Widget _storiesRow(
    BuildContext context,
    Map<String, List<Story>> stories,
    User? me,
  ) {
    return Container(
      height: 96,
      decoration: const BoxDecoration(
        color: BlueSnapTheme.bgSecondary,
        border: Border(
          bottom: BorderSide(color: BlueSnapTheme.divider, width: 0.5),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16, top: 12),
        children: [
          _myStoryItem(context, me),
          const SizedBox(width: 14),
          ...stories.entries.expand((e) {
            final authorStories = e.value;
            final s = authorStories.first;
            return [
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StoryViewerScreen(stories: authorStories),
                  ),
                ),
                child: _storyItem(
                  s.authorName.split(' ').first,
                  s.authorAvatarColorIndex,
                  viewed: s.isViewed,
                ),
              ),
              const SizedBox(width: 14),
            ];
          }),
        ],
      ),
    );
  }

  Widget _myStoryItem(BuildContext context, User? me) {
    return GestureDetector(
      // Camera-first, like Snapchat: capture, then post to your story.
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CameraScreen()),
      ),
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                UserAvatar(
                  name: me?.displayName ?? 'Me',
                  colorIndex: me?.avatarColorIndex ?? 0,
                  imagePath: me?.avatarPath,
                  size: 62,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: BlueSnapTheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: BlueSnapTheme.bgSecondary, width: 2),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Your story',
              style: BlueSnapTheme.timestamp.copyWith(
                color: BlueSnapTheme.textSecondary,
                fontSize: 10,
                letterSpacing: 0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _storyItem(String name, int colorIndex, {bool viewed = false}) {
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          UserAvatar(
            name: name,
            colorIndex: colorIndex,
            size: 62,
            hasStory: true,
            storyViewed: viewed,
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: TextStyle(
              fontFamily: BlueSnapTheme.fontFamily,
              fontSize: 10,
              color: viewed
                  ? BlueSnapTheme.textSecondary
                  : BlueSnapTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ══ Post card ═══════════════════════════════════════════
  Widget _postCard(
      BuildContext context, WidgetRef ref, Post post, Set<String> bookmarks) {
    final isBookmarked = bookmarks.contains(post.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header row ──────────────
        SizedBox(
          height: 54,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                UserAvatar(
                  name: post.authorName,
                  colorIndex: post.authorAvatarColorIndex,
                  size: 32,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(post.authorName, style: BlueSnapTheme.username),
                ),
                GestureDetector(
                  onTap: () => _postMenu(context, ref, post),
                  behavior: HitTestBehavior.opaque,
                  child: const Icon(Icons.more_horiz,
                      size: 18, color: BlueSnapTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),

        // ── Media / text-only body ──
        if (post.mediaPath != null)
          _DoubleTapLikeMedia(
            post: post,
            onLike: () => ref.read(postsProvider.notifier).toggleLike(post.id),
            onOpen: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
            ).then((_) => ref.read(postsProvider.notifier).refresh()),
          )
        else if (post.textContent != null)
          _textPost(post)
        else
          const SizedBox(height: 8),

        // ── Action bar ──────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              _AnimatedLike(
                liked: post.isLikedByMe,
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(postsProvider.notifier).toggleLike(post.id);
                },
              ),
              const SizedBox(width: 18),
              _action(AppIcons.comment,
                  onTap: () => _openComments(context, ref, post)),
              const SizedBox(width: 18),
              _action(AppIcons.repost,
                  onTap: () => _repost(context, ref, post)),
              const SizedBox(width: 18),
              _action(AppIcons.share,
                  onTap: () => _sharePost(context, ref, post)),
              const Spacer(),
              _action(
                isBookmarked ? AppIcons.bookmarkBold : AppIcons.bookmark,
                color: isBookmarked ? BlueSnapTheme.textPrimary : null,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(bookmarksProvider.notifier).toggle(post.id);
                },
              ),
            ],
          ),
        ),

        // ── Like count ──────────────
        if (post.likeCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '${post.likeCount} ${post.likeCount == 1 ? 'like' : 'likes'}',
              style: BlueSnapTheme.username.copyWith(fontSize: 13),
            ),
          ),

        // ── Caption ─────────────────
        if (post.textContent != null && post.mediaPath != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: _caption(post),
          ),

        // ── Comments link ───────────
        if (post.commentCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: GestureDetector(
              onTap: () => _openComments(context, ref, post),
              child: Text(
                'View all ${post.commentCount} comments',
                style: BlueSnapTheme.caption
                    .copyWith(color: BlueSnapTheme.textSecondary, fontSize: 12),
              ),
            ),
          ),

        // ── Timestamp ───────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Text(_timeAgo(post.createdAt), style: BlueSnapTheme.timestamp),
        ),

        const SizedBox(height: 12),
        const ThinDivider(),
      ],
    );
  }

  Widget _textPost(Post post) {
    final color = AvatarColors.fromIndex(post.authorAvatarColorIndex);
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 220, maxHeight: 340),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.10),
            color.withValues(alpha: 0.05),
          ],
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Text(
        post.textContent!,
        textAlign: TextAlign.center,
        style: BlueSnapTheme.bodyL.copyWith(fontSize: 16, height: 1.4),
      ),
    );
  }

  Widget _caption(Post post) {
    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: BlueSnapTheme.bodyM.copyWith(fontSize: 13),
        children: [
          TextSpan(
            text: '${post.authorName} ',
            style: BlueSnapTheme.username.copyWith(fontSize: 13),
          ),
          TextSpan(text: post.textContent!),
        ],
      ),
    );
  }

  Widget _action(IconData icon, {Color? color, VoidCallback? onTap}) {
    return Pressable(
      onTap: onTap,
      child: Icon(icon, size: 24, color: color ?? BlueSnapTheme.textPrimary),
    );
  }

  void _openComments(BuildContext context, WidgetRef ref, Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: CommentsSheet(post: post),
      ),
    ).then((_) => ref.read(postsProvider.notifier).refresh());
  }

  // Real repost: reshare the post to your own feed + to people nearby.
  void _repost(BuildContext context, WidgetRef ref, Post post) {
    final me = ref.read(currentUserProvider);
    if (me == null) return;
    HapticFeedback.lightImpact();

    final id = '${DateTime.now().millisecondsSinceEpoch}';
    final repost = Post(
      id: id,
      authorId: me.id,
      authorName: me.displayName,
      authorAvatarColorIndex: me.avatarColorIndex,
      textContent: post.textContent ?? (post.mediaPath != null ? '' : null),
      mediaPath: post.mediaPath,
      isVideo: post.isVideo,
    );
    final db = ref.read(databaseProvider);
    db.savePost(repost);
    db.recordShared(id);

    // Propagate the text to connected peers (media stays local).
    if ((post.textContent ?? '').isNotEmpty) {
      BluetoothService().broadcastFeed({
        'type': 'post',
        'id': id,
        'authorId': me.id,
        'authorName': me.displayName,
        'color': me.avatarColorIndex,
        'text': post.textContent,
        'createdAt': repost.createdAt.toIso8601String(),
      });
    }

    post.shareCount += 1;
    db.savePost(post);
    ref.read(postsProvider.notifier).refresh();
    showAppSnack(context, 'Reposted to your profile', icon: AppIcons.repost);
  }

  void _postMenu(BuildContext context, WidgetRef ref, Post post) {
    final myId = ref.read(currentUserProvider)?.id;
    final isMine = post.authorId == myId;
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
            const SizedBox(height: 8),
            if (isMine)
              // You can only delete your own posts.
              ListTile(
                leading: const Icon(Icons.delete_outline, color: BlueSnapTheme.accentRed),
                title: const Text('Delete post',
                    style: TextStyle(color: BlueSnapTheme.accentRed,
                        fontWeight: FontWeight.w600)),
                onTap: () {
                  ref.read(postsProvider.notifier).deletePost(post.id);
                  Navigator.pop(context);
                  showAppSnack(context, 'Post deleted', icon: Icons.delete_outline);
                },
              )
            else
              // Others' posts can't be deleted — only hidden from your feed.
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined),
                title: const Text('Not interested', style: BlueSnapTheme.username),
                subtitle: const Text('Hide this from your feed',
                    style: BlueSnapTheme.bodyS),
                onTap: () {
                  ref.read(postsProvider.notifier).hidePost(post.id);
                  Navigator.pop(context);
                  showAppSnack(context, "You won't see this post again",
                      icon: Icons.visibility_off_outlined);
                },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel', style: BlueSnapTheme.username),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _sharePost(BuildContext context, WidgetRef ref, Post post) {
    final bt = BluetoothService();
    final devices = bt.discoveredDevices;

    if (devices.isEmpty) {
      showAppSnack(context, 'No one nearby to share with right now.',
          icon: Icons.send_outlined, isError: true);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: BlueSnapTheme.bgCard,
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
                  color: BlueSnapTheme.surface3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Share', style: BlueSnapTheme.headingS),
              ),
              const ThinDivider(),
              ...devices.take(8).map((device) {
                return ListTile(
                  leading: UserAvatar(
                    name: device.userName,
                    colorIndex: device.avatarColorIndex,
                    size: 44,
                  ),
                  title: Text(device.userName, style: BlueSnapTheme.username),
                  trailing: const Icon(Icons.send_rounded,
                      color: BlueSnapTheme.primary, size: 20),
                  onTap: () {
                    final content = post.textContent ?? '[Shared post]';
                    bt.sendMessage(Message(
                      id: '${DateTime.now().millisecondsSinceEpoch}',
                      conversationId: 'conv_${device.deviceId}',
                      senderId: ref.read(currentUserProvider)?.id ?? '',
                      receiverId: device.deviceId,
                      content: '[Shared Post] $content',
                      messageTypeIndex: MessageType.text.index,
                      statusIndex: MessageStatus.sending.index,
                    ));
                    post.shareCount += 1;
                    ref.read(databaseProvider).savePost(post);
                    ref.read(databaseProvider).recordShared(post.id);
                    ref.read(postsProvider.notifier).refresh();
                    Navigator.pop(context);
                    showAppSnack(context, 'Shared with ${device.userName}',
                        icon: Icons.send_rounded);
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

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'JUST NOW';
    if (diff.inHours < 1) {
      return '${diff.inMinutes} ${diff.inMinutes == 1 ? 'MINUTE' : 'MINUTES'} AGO';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} ${diff.inHours == 1 ? 'HOUR' : 'HOURS'} AGO';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} ${diff.inDays == 1 ? 'DAY' : 'DAYS'} AGO';
    }
    return DateFormat.MMMd().format(time).toUpperCase();
  }
}

// ══════════════════════════════════════════════════════════
// Animated like button — springy pop + colour flip on tap.
// ══════════════════════════════════════════════════════════
class _AnimatedLike extends StatefulWidget {
  final bool liked;
  final VoidCallback onTap;
  const _AnimatedLike({required this.liked, required this.onTap});

  @override
  State<_AnimatedLike> createState() => _AnimatedLikeState();
}

class _AnimatedLikeState extends State<_AnimatedLike>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.75), weight: 30),
    TweenSequenceItem(
        tween: Tween(begin: 0.75, end: 1.25)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 30),
  ]).animate(_c);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _tap() {
    if (!widget.liked) _c.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _tap,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scale,
        child: Icon(
          widget.liked ? AppIcons.likeBold : AppIcons.like,
          size: 25,
          color: widget.liked ? BlueSnapTheme.likeRed : BlueSnapTheme.textPrimary,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Double-tap-to-like media — Instagram/Snapchat style heart burst.
// ══════════════════════════════════════════════════════════
class _DoubleTapLikeMedia extends StatefulWidget {
  final Post post;
  final VoidCallback onLike;
  final VoidCallback onOpen;
  const _DoubleTapLikeMedia({
    required this.post,
    required this.onLike,
    required this.onOpen,
  });

  @override
  State<_DoubleTapLikeMedia> createState() => _DoubleTapLikeMediaState();
}

class _DoubleTapLikeMediaState extends State<_DoubleTapLikeMedia>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    HapticFeedback.mediumImpact();
    if (!widget.post.isLikedByMe) widget.onLike();
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onOpen,
      onDoubleTap: _onDoubleTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          alignment: Alignment.center,
          children: [
            MediaImage(
              path: widget.post.mediaPath!,
              width: double.infinity,
              height: double.infinity,
              isVideo: widget.post.isVideo,
              fallbackColor:
                  AvatarColors.fromIndex(widget.post.authorAvatarColorIndex),
            ),
            if (widget.post.isVideo)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(AppIcons.play, color: Colors.white, size: 36),
              ),
            // Heart burst on double-tap.
            AnimatedBuilder(
              animation: _c,
              builder: (_, __) {
                final t = _c.value;
                if (t == 0) return const SizedBox.shrink();
                final scale = t < 0.4
                    ? Curves.easeOutBack.transform(t / 0.4) * 1.1
                    : 1.1 - (t - 0.4) / 0.6 * 0.1;
                final opacity = t < 0.6 ? 1.0 : (1 - (t - 0.6) / 0.4);
                return Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: scale,
                    child: const Icon(AppIcons.likeBold,
                        color: Colors.white, size: 96,
                        shadows: [Shadow(color: Colors.black38, blurRadius: 12)]),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
