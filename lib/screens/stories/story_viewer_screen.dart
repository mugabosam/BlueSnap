/// BlueSnap Story Viewer
/// Fullscreen story viewer with progress bars, auto-advance,
/// tap to skip, swipe to next person, and reactions.
library;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../data/models/models.dart';
import '../../data/database/database_service.dart';
import '../../services/bluetooth_service.dart';
import '../../widgets/shared_widgets.dart';

class StoryViewerScreen extends StatefulWidget {
  final List<Story> stories; // Stories from one author
  final VoidCallback? onComplete;

  const StoryViewerScreen({
    super.key,
    required this.stories,
    this.onComplete,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _progressController;
  final _replyController = TextEditingController();
  bool _showReplyBar = false;

  Story get _currentStory => widget.stories[_currentIndex];

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });
    _startStory();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _startStory() {
    _progressController.reset();
    _progressController.forward();
    // Mark as viewed
    _currentStory.isViewed = true;
    _currentStory.viewCount += 1;
    _currentStory.save();
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() => _currentIndex++);
      _startStory();
    } else {
      widget.onComplete?.call();
      Navigator.of(context).pop();
    }
  }

  void _prevStory() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _startStory();
    } else {
      _progressController.reset();
      _progressController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = _currentStory;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < screenWidth / 3) {
            _prevStory();
          } else if (details.globalPosition.dx > screenWidth * 2 / 3) {
            _nextStory();
          } else {
            // Center tap — pause/resume
            if (_progressController.isAnimating) {
              _progressController.stop();
            } else {
              _progressController.forward();
            }
          }
        },
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
            Navigator.of(context).pop();
          }
        },
        child: Stack(
          children: [
            // Story background — real image if present, else branded gradient
            Positioned.fill(
              child: story.mediaPath != null
                  ? MediaImage(
                      path: story.mediaPath!,
                      fit: BoxFit.cover,
                      fallbackColor:
                          AvatarColors.fromIndex(story.authorAvatarColorIndex),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AvatarColors.fromIndex(story.authorAvatarColorIndex).withValues(alpha: 0.4),
                            Colors.black,
                            AvatarColors.fromIndex(story.authorAvatarColorIndex).withValues(alpha: 0.2),
                          ],
                        ),
                      ),
                    ),
            ),

            // Text overlay (with scrim for legibility over photos)
            if ((story.textOverlay ?? '').isNotEmpty)
              Positioned.fill(
                child: Container(
                  color: story.mediaPath != null
                      ? Colors.black.withValues(alpha: 0.25)
                      : Colors.transparent,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    story.textOverlay!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      fontFamily: BlueSnapTheme.fontFamily,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // Progress bars
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: List.generate(widget.stories.length, (i) {
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: 2.5,
                          child: AnimatedBuilder(
                            animation: _progressController,
                            builder: (_, __) {
                              double progress;
                              if (i < _currentIndex) {
                                progress = 1.0;
                              } else if (i == _currentIndex) {
                                progress = _progressController.value;
                              } else {
                                progress = 0.0;
                              }
                              return LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation(Colors.white),
                                minHeight: 2.5,
                              );
                            },
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),

            // Author info
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 20, 12, 0),
                  child: Row(
                    children: [
                      UserAvatar(
                        name: story.authorName,
                        colorIndex: story.authorAvatarColorIndex,
                        size: 36,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              story.authorName,
                              style: const TextStyle(
                                color: Colors.white, fontSize: 14,
                                fontWeight: FontWeight.w700,
                                fontFamily: BlueSnapTheme.fontFamily,
                              ),
                            ),
                            Text(
                              _timeAgo(story.createdAt),
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      // Bluetooth badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: BlueSnapTheme.primary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bluetooth, size: 12, color: BlueSnapTheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              '${story.viewCount} views',
                              style: const TextStyle(color: BlueSnapTheme.primary, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Icon(Icons.close, color: Colors.white, size: 24),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom — reply bar or reaction buttons
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: SafeArea(
                child: _showReplyBar ? _buildReplyBar() : _buildReactionBar(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          // Reply input trigger
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showReplyBar = true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white24, width: 0.5),
                ),
                child: const Text(
                  'Reply...',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Quick reactions
          _reactionButton('🔥'),
          _reactionButton('😂'),
          _reactionButton('❤️'),
          // Share
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {},
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyBar() {
    _progressController.stop(); // Pause story while typing
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: Colors.black54,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Reply to ${_currentStory.authorName.split(' ').first}...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white12,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) {
                _sendReply(_replyController.text.trim());
              },
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() { _showReplyBar = false; _replyController.clear(); });
              _progressController.forward();
            },
            child: const Icon(Icons.close, color: Colors.white54, size: 24),
          ),
        ],
      ),
    );
  }

  void _sendReply(String text) {
    if (text.isEmpty) return;
    final db = DatabaseService();
    final user = db.currentUser;
    if (user == null) return;

    final story = _currentStory;
    final bt = BluetoothService();
    final uuid = const Uuid();

    // Create a message to the story author
    final convId = 'conv_${story.authorId}';
    final msg = Message(
      id: uuid.v4(),
      conversationId: convId,
      senderId: user.id,
      receiverId: story.authorId,
      content: '[Story Reply] $text',
      messageTypeIndex: MessageType.text.index,
      statusIndex: MessageStatus.sending.index,
    );
    db.saveMessage(msg);

    // Ensure conversation exists
    var conv = db.getConversationByPeer(story.authorId);
    if (conv == null) {
      conv = Conversation(
        id: convId,
        peerId: story.authorId,
        peerName: story.authorName,
        peerAvatarColorIndex: story.authorAvatarColorIndex,
      );
      db.saveConversation(conv);
    }
    conv.lastMessage = '[Story Reply] $text';
    conv.lastMessageTime = DateTime.now();
    conv.save();

    bt.sendMessage(msg);

    setState(() { _showReplyBar = false; _replyController.clear(); });
    _progressController.forward();

    showAppSnack(context, 'Reply sent',
        icon: Icons.bluetooth_rounded);
  }

  void _sendReaction(String emoji) {
    final db = DatabaseService();
    final user = db.currentUser;
    if (user == null) return;

    final story = _currentStory;
    final bt = BluetoothService();
    final uuid = const Uuid();

    final convId = 'conv_${story.authorId}';
    final msg = Message(
      id: uuid.v4(),
      conversationId: convId,
      senderId: user.id,
      receiverId: story.authorId,
      content: '$emoji (reaction to story)',
      messageTypeIndex: MessageType.text.index,
      statusIndex: MessageStatus.sending.index,
    );
    db.saveMessage(msg);

    var conv = db.getConversationByPeer(story.authorId);
    if (conv == null) {
      conv = Conversation(
        id: convId,
        peerId: story.authorId,
        peerName: story.authorName,
        peerAvatarColorIndex: story.authorAvatarColorIndex,
      );
      db.saveConversation(conv);
    }
    conv.lastMessage = '$emoji (reaction to story)';
    conv.lastMessageTime = DateTime.now();
    conv.save();

    bt.sendMessage(msg);

    showAppSnack(context, '$emoji sent', icon: Icons.favorite_rounded);
  }

  Widget _reactionButton(String emoji) {
    return GestureDetector(
      onTap: () => _sendReaction(emoji),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
