/// BlueSnap Messages list
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../data/models/models.dart';
import '../../core/app_icons.dart';
import '../../providers/providers.dart';
import '../../services/streak_service.dart';
import '../../widgets/shared_widgets.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  final void Function(Conversation conversation) onConversationTap;
  const ChatListScreen({super.key, required this.onConversationTap});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationsProvider);

    final filtered = _searchQuery.isEmpty
        ? conversations
        : conversations
            .where((c) =>
                c.peerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (c.lastMessage?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                    false))
            .toList();

    return Scaffold(
      backgroundColor: BlueSnapTheme.bgPrimary,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: const [
                  Text('Messages', style: BlueSnapTheme.headingL),
                  Spacer(),
                  Icon(AppIcons.create,
                      size: 24, color: BlueSnapTheme.textPrimary),
                ],
              ),
            ),

            // ── Search ──────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: BlueSnapTheme.surface2,
                  borderRadius: BorderRadius.circular(BlueSnapTheme.radiusM),
                ),
                child: Row(
                  children: [
                    const Icon(AppIcons.search,
                        color: BlueSnapTheme.textTertiary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: BlueSnapTheme.bodyM,
                        cursorColor: BlueSnapTheme.primary,
                        decoration: InputDecoration(
                          isCollapsed: true,
                          hintText: 'Search',
                          hintStyle: BlueSnapTheme.bodyM
                              .copyWith(color: BlueSnapTheme.textTertiary),
                          border: InputBorder.none,
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: const Icon(Icons.close,
                            color: BlueSnapTheme.textTertiary, size: 16),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Conversation List ───────────
            Expanded(
              child: filtered.isEmpty
                  ? EmptyState(
                      icon: _searchQuery.isNotEmpty
                          ? Icons.search_off_rounded
                          : Icons.chat_bubble_outline_rounded,
                      title: _searchQuery.isNotEmpty
                          ? 'No results'
                          : 'No messages yet',
                      subtitle: _searchQuery.isNotEmpty
                          ? 'Try a different search term'
                          : 'Find people in Search and start a conversation.',
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const ThinDivider(indent: 76),
                      itemBuilder: (_, i) => _conversationTile(filtered[i])
                          .animate()
                          .fadeIn(duration: 200.ms, delay: (i * 30).ms),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conversationTile(Conversation conv) {
    final hasUnread = conv.unreadCount > 0;
    final timeStr =
        conv.lastMessageTime != null ? _formatTime(conv.lastMessageTime!) : '';

    return Material(
      color: BlueSnapTheme.bgSecondary,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onConversationTap(conv);
        },
        child: SizedBox(
          height: 72,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                UserAvatar(
                  name: conv.peerName,
                  colorIndex: conv.peerAvatarColorIndex,
                  size: 52,
                  showOnlineIndicator: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              conv.peerName,
                              style: BlueSnapTheme.username.copyWith(fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _streakBadge(conv.id),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        conv.lastMessage ?? 'Say hi 👋',
                        style: BlueSnapTheme.bodyM.copyWith(
                          color: hasUnread
                              ? BlueSnapTheme.textPrimary
                              : BlueSnapTheme.textSecondary,
                          fontWeight:
                              hasUnread ? FontWeight.w600 : FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(timeStr, style: BlueSnapTheme.timestamp),
                    const SizedBox(height: 6),
                    if (hasUnread)
                      Container(
                        constraints:
                            const BoxConstraints(minWidth: 18, minHeight: 18),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: BlueSnapTheme.primary,
                          borderRadius:
                              BorderRadius.circular(BlueSnapTheme.radiusFull),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${conv.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            fontFeatures: BlueSnapTheme.tabular,
                            fontFamily: BlueSnapTheme.fontFamily,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 18),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 🔥 N when a conversation is on a streak; ⌛ warns it's about to lapse.
  Widget _streakBadge(String convId) {
    final count = StreakService().streakFor(convId);
    if (count <= 0) return const SizedBox.shrink();
    final atRisk = StreakService().isAtRisk(convId);
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(atRisk ? '⌛' : '🔥', style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 1),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: atRisk ? BlueSnapTheme.accentOrange : BlueSnapTheme.textPrimary,
              fontFamily: BlueSnapTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return DateFormat.E().format(time);
    return DateFormat.MMMd().format(time);
  }
}
