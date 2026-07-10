/// BlueSnap Post Detail — full view of a single post, opened from the
/// profile grid (or anywhere a compact tile is shown). The author can delete
/// their post from here; anyone can like, comment, or hide it.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/comments_sheet.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final Post post;
  const PostDetailScreen({super.key, required this.post});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final me = ref.watch(currentUserProvider);
    final isMine = post.authorId == me?.id;
    final color = AvatarColors.fromIndex(post.authorAvatarColorIndex);

    return Scaffold(
      backgroundColor: BlueSnapTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: BlueSnapTheme.bgSecondary,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: BlueSnapTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Post', style: BlueSnapTheme.headingS),
        centerTitle: true,
        actions: [
          if (isMine)
            IconButton(
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete_outline,
                  size: 22, color: BlueSnapTheme.accentRed),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Author row ─────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  UserAvatar(
                    name: post.authorName,
                    colorIndex: post.authorAvatarColorIndex,
                    imagePath: isMine ? me?.avatarPath : null,
                    size: 36,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(post.authorName, style: BlueSnapTheme.username),
                  ),
                  Text(
                    DateFormat.yMMMd().format(post.createdAt),
                    style: BlueSnapTheme.timestamp,
                  ),
                ],
              ),
            ),

            // ── Media / text body ──────────
            if (post.mediaPath != null)
              AspectRatio(
                aspectRatio: 1,
                child: MediaImage(
                  path: post.mediaPath!,
                  fit: BoxFit.cover,
                  isVideo: post.isVideo,
                  fallbackColor: color,
                ),
              )
            else if (post.textContent != null)
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 200),
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
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                child: Text(
                  post.textContent!,
                  textAlign: TextAlign.center,
                  style: BlueSnapTheme.bodyL.copyWith(fontSize: 18, height: 1.4),
                ),
              ),

            // ── Actions ────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(postsProvider.notifier).toggleLike(post.id);
                      setState(() {});
                    },
                    child: Icon(
                      post.isLikedByMe
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 26,
                      color: post.isLikedByMe
                          ? BlueSnapTheme.likeRed
                          : BlueSnapTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 18),
                  GestureDetector(
                    onTap: _openComments,
                    child: const Icon(Icons.mode_comment_outlined, size: 24),
                  ),
                ],
              ),
            ),

            // ── Counts + caption ───────────
            if (post.likeCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Text(
                  '${post.likeCount} ${post.likeCount == 1 ? 'like' : 'likes'}',
                  style: BlueSnapTheme.username.copyWith(fontSize: 13),
                ),
              ),
            if (post.textContent != null && post.mediaPath != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(post.textContent!, style: BlueSnapTheme.bodyM),
              ),
            if (post.commentCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: GestureDetector(
                  onTap: _openComments,
                  child: Text(
                    'View all ${post.commentCount} comments',
                    style: BlueSnapTheme.caption
                        .copyWith(color: BlueSnapTheme.textSecondary, fontSize: 12),
                  ),
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: CommentsSheet(post: widget.post),
      ),
    ).then((_) {
      ref.read(postsProvider.notifier).refresh();
      if (mounted) setState(() {});
    });
  }

  Future<void> _confirmDelete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: BlueSnapTheme.bgCard,
        title: const Text('Delete post?', style: BlueSnapTheme.headingS),
        content: const Text("This can't be undone.", style: BlueSnapTheme.bodyS),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: BlueSnapTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: BlueSnapTheme.accentRed)),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await ref.read(postsProvider.notifier).deletePost(widget.post.id);
      if (mounted) {
        Navigator.pop(context);
        showAppSnack(context, 'Post deleted', icon: Icons.delete_outline);
      }
    }
  }
}
