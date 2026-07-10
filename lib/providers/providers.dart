/// BlueSnap Riverpod providers
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/database_service.dart';
import '../data/models/models.dart';
import '../services/bluetooth_service.dart';
import '../services/streak_service.dart';

// ── Services ─────────────────────────────────────────────
final databaseProvider = Provider<DatabaseService>((ref) => DatabaseService());
final bluetoothProvider = ChangeNotifierProvider<BluetoothService>((ref) => BluetoothService());

// ── Current User ─────────────────────────────────────────
final currentUserProvider = StateProvider<User?>((ref) {
  final db = ref.read(databaseProvider);
  return db.currentUser;
});

// ── Conversations ────────────────────────────────────────
final conversationsProvider = StateNotifierProvider<ConversationsNotifier, List<Conversation>>((ref) {
  return ConversationsNotifier(ref.read(databaseProvider));
});

class ConversationsNotifier extends StateNotifier<List<Conversation>> {
  final DatabaseService _db;
  ConversationsNotifier(this._db) : super(_db.allConversations);

  void refresh() => state = _db.allConversations;

  Future<Conversation> getOrCreate(String peerId, String peerName, int colorIndex) async {
    var conv = _db.getConversationByPeer(peerId);
    if (conv == null) {
      conv = Conversation(
        id: 'conv_$peerId',
        peerId: peerId,
        peerName: peerName,
        peerAvatarColorIndex: colorIndex,
      );
      await _db.saveConversation(conv);
      refresh();
    }
    return conv;
  }

  Future<void> updateLastMessage(String convId, String text) async {
    final conv = _db.getConversation(convId);
    if (conv != null) {
      conv.lastMessage = text;
      conv.lastMessageTime = DateTime.now();
      await conv.save();
      // Every outgoing message counts toward today's streak.
      await StreakService().recordMine(convId);
      refresh();
    }
  }
}

// ── Messages for a conversation ──────────────────────────
final messagesProvider = StateNotifierProvider.family<MessagesNotifier, List<Message>, String>(
  (ref, conversationId) => MessagesNotifier(ref.read(databaseProvider), conversationId),
);

class MessagesNotifier extends StateNotifier<List<Message>> {
  final DatabaseService _db;
  final String conversationId;

  MessagesNotifier(this._db, this.conversationId)
      : super(_db.getMessages(conversationId));

  void refresh() => state = _db.getMessages(conversationId);

  Future<void> addMessage(Message m) async {
    await _db.saveMessage(m);
    refresh();
  }
}

// ── Posts (Feed) ─────────────────────────────────────────
final postsProvider = StateNotifierProvider<PostsNotifier, List<Post>>((ref) {
  return PostsNotifier(ref.read(databaseProvider));
});

class PostsNotifier extends StateNotifier<List<Post>> {
  final DatabaseService _db;
  PostsNotifier(this._db) : super(_db.allPosts);

  void refresh() => state = _db.allPosts;

  Future<void> toggleLike(String postId) async {
    final post = state.firstWhere((p) => p.id == postId);
    post.isLikedByMe = !post.isLikedByMe;
    post.likeCount += post.isLikedByMe ? 1 : -1;
    await _db.savePost(post);
    refresh();
  }

  /// Delete a post (only allowed for the author — enforced in the UI).
  Future<void> deletePost(String postId) async {
    await _db.deletePost(postId);
    refresh();
  }

  /// Hide someone else's post from your feed ("Not interested").
  Future<void> hidePost(String postId) async {
    await _db.hidePost(postId);
    refresh();
  }
}

// ── Stories ──────────────────────────────────────────────
final storiesProvider = StateNotifierProvider<StoriesNotifier, Map<String, List<Story>>>((ref) {
  return StoriesNotifier(ref.read(databaseProvider));
});

class StoriesNotifier extends StateNotifier<Map<String, List<Story>>> {
  final DatabaseService _db;
  StoriesNotifier(this._db) : super(_db.storiesByAuthor);

  void refresh() => state = _db.storiesByAuthor;
}

// ── Comments ────────────────────────────────────────────
final commentsProvider = StateNotifierProvider.family<CommentsNotifier, List<Comment>, String>(
  (ref, postId) => CommentsNotifier(ref.read(databaseProvider), postId),
);

class CommentsNotifier extends StateNotifier<List<Comment>> {
  final DatabaseService _db;
  final String postId;

  CommentsNotifier(this._db, this.postId) : super(_db.getComments(postId));

  void refresh() => state = _db.getComments(postId);

  Future<void> addComment(Comment c) async {
    await _db.saveComment(c);
    // Update post comment count
    try {
      final posts = _db.allPosts;
      final post = posts.firstWhere((p) => p.id == postId);
      post.commentCount = _db.getCommentCount(postId);
      await _db.savePost(post);
    } catch (_) {}
    refresh();
  }

  Future<void> toggleLike(String commentId) async {
    final comment = state.firstWhere((c) => c.id == commentId);
    comment.isLikedByMe = !comment.isLikedByMe;
    comment.likeCount += comment.isLikedByMe ? 1 : -1;
    await _db.saveComment(comment);
    refresh();
  }
}

// ── Bookmarks ───────────────────────────────────────────
final bookmarksProvider = StateNotifierProvider<BookmarksNotifier, Set<String>>((ref) {
  return BookmarksNotifier(ref.read(databaseProvider));
});

class BookmarksNotifier extends StateNotifier<Set<String>> {
  final DatabaseService _db;
  BookmarksNotifier(this._db) : super(_db.bookmarkedPostIds);

  Future<void> toggle(String postId) async {
    await _db.toggleBookmark(postId);
    state = _db.bookmarkedPostIds;
  }
}

// ── Nearby Devices ───────────────────────────────────────
final nearbyDevicesProvider = Provider<List<NearbyDevice>>((ref) {
  final bt = ref.watch(bluetoothProvider);
  return bt.discoveredDevices;
});

// ── Navigation State ─────────────────────────────────────
final currentTabProvider = StateProvider<int>((ref) => 0);
