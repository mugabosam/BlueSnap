/// BlueSnap Comments Bottom Sheet
/// Shows comments for a post with ability to add new comments.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/theme.dart';
import '../data/models/models.dart';
import '../providers/providers.dart';
import 'shared_widgets.dart';

class CommentsSheet extends ConsumerStatefulWidget {
  final Post post;

  const CommentsSheet({super.key, required this.post});

  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  final _controller = TextEditingController();
  final _uuid = const Uuid();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(commentsProvider(widget.post.id));
    final user = ref.watch(currentUserProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: BlueSnapTheme.bgSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: BlueSnapTheme.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Text(
                  'Comments',
                  style: BlueSnapTheme.headingS,
                ),
                const SizedBox(width: 8),
                Text(
                  '${comments.length}',
                  style: BlueSnapTheme.bodyS.copyWith(
                    color: BlueSnapTheme.textTertiary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: BlueSnapTheme.textTertiary, size: 22),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: BlueSnapTheme.divider),

          // Comments list
          Expanded(
            child: comments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 48, color: BlueSnapTheme.textTertiary),
                        const SizedBox(height: 12),
                        Text('No comments yet', style: BlueSnapTheme.bodyS),
                        const SizedBox(height: 4),
                        Text(
                          'Be the first to comment',
                          style: BlueSnapTheme.caption,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: comments.length,
                    itemBuilder: (_, i) => _commentTile(comments[i]),
                  ),
          ),

          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: const BoxDecoration(
              color: BlueSnapTheme.bgPrimary,
              border: Border(
                top: BorderSide(color: BlueSnapTheme.divider, width: 0.5),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  if (user != null)
                    UserAvatar(
                      name: user.displayName,
                      colorIndex: user.avatarColorIndex,
                      size: 32,
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: BlueSnapTheme.bgInput,
                        borderRadius: BorderRadius.circular(BlueSnapTheme.radiusFull),
                      ),
                      child: TextField(
                        controller: _controller,
                        style: BlueSnapTheme.bodyM.copyWith(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: BlueSnapTheme.bodyM.copyWith(
                            color: BlueSnapTheme.textTertiary,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onSubmitted: (_) => _submitComment(user),
                        textInputAction: TextInputAction.send,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _controller.text.trim().isNotEmpty
                        ? () => _submitComment(user)
                        : null,
                    child: Icon(
                      Icons.send_rounded,
                      color: _controller.text.trim().isNotEmpty
                          ? BlueSnapTheme.primary
                          : BlueSnapTheme.textTertiary,
                      size: 24,
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

  Widget _commentTile(Comment comment) {
    final timeAgo = _timeAgo(comment.createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            name: comment.authorName,
            colorIndex: comment.authorAvatarColorIndex,
            size: 32,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.authorName,
                      style: BlueSnapTheme.bodyS.copyWith(
                        fontWeight: FontWeight.w700,
                        color: BlueSnapTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(timeAgo, style: BlueSnapTheme.caption),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  comment.content,
                  style: BlueSnapTheme.bodyM.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => ref.read(commentsProvider(widget.post.id).notifier).toggleLike(comment.id),
                      child: Row(
                        children: [
                          Icon(
                            comment.isLikedByMe ? Icons.favorite : Icons.favorite_border,
                            size: 14,
                            color: comment.isLikedByMe ? BlueSnapTheme.accentRed : BlueSnapTheme.textTertiary,
                          ),
                          if (comment.likeCount > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '${comment.likeCount}',
                              style: BlueSnapTheme.caption.copyWith(fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Reply',
                      style: BlueSnapTheme.caption.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _submitComment(User? user) {
    final text = _controller.text.trim();
    if (text.isEmpty || user == null) return;

    _controller.clear();

    final comment = Comment(
      id: _uuid.v4(),
      postId: widget.post.id,
      authorId: user.id,
      authorName: user.displayName,
      authorAvatarColorIndex: user.avatarColorIndex,
      content: text,
    );

    ref.read(commentsProvider(widget.post.id).notifier).addComment(comment);
    ref.read(postsProvider.notifier).refresh();
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
