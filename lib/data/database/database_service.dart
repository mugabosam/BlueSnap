/// BlueSnap local database (Hive)
library;

import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';
import 'adapters.dart';
import '../../core/constants.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._();
  factory DatabaseService() => _instance;
  DatabaseService._();

  late Box<User> _usersBox;
  late Box<Conversation> _conversationsBox;
  late Box<Message> _messagesBox;
  late Box<Post> _postsBox;
  late Box<Story> _storiesBox;
  late Box<NearbyDevice> _nearbyBox;
  late Box<Comment> _commentsBox;
  late Box<QueuedMessage> _queuedBox;
  late Box _settingsBox;
  /// Secondary index: conversationId -> ordered list of message ids. Avoids a
  /// full scan of every message on each conversation open / refresh.
  late Box _msgIndexBox;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    registerAdapters();

    _usersBox = await Hive.openBox<User>(AppConstants.dbUsers);
    _conversationsBox = await Hive.openBox<Conversation>(AppConstants.dbConversations);
    _messagesBox = await Hive.openBox<Message>(AppConstants.dbMessages);
    _postsBox = await Hive.openBox<Post>(AppConstants.dbPosts);
    _storiesBox = await Hive.openBox<Story>(AppConstants.dbStories);
    _nearbyBox = await Hive.openBox<NearbyDevice>(AppConstants.dbNearbyDevices);
    _commentsBox = await Hive.openBox<Comment>('comments');
    _queuedBox = await Hive.openBox<QueuedMessage>('queued_messages');
    _settingsBox = await Hive.openBox(AppConstants.dbSettings);
    _msgIndexBox = await Hive.openBox('message_index');

    _initialized = true;
  }

  // ── Current User ───────────────────────────────────────
  User? get currentUser {
    try {
      return _usersBox.values.firstWhere((u) => u.isCurrentUser);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCurrentUser(User user) async {
    user.isCurrentUser = true;
    await _usersBox.put(user.id, user);
  }

  bool get hasCurrentUser => currentUser != null;

  // ── Users ──────────────────────────────────────────────
  Future<void> saveUser(User user) => _usersBox.put(user.id, user);
  User? getUser(String id) => _usersBox.get(id);
  List<User> get allUsers => _usersBox.values.toList();

  // ── Conversations ──────────────────────────────────────
  Future<void> saveConversation(Conversation c) => _conversationsBox.put(c.id, c);
  Conversation? getConversation(String id) => _conversationsBox.get(id);

  List<Conversation> get allConversations {
    final list = _conversationsBox.values.toList();
    list.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final at = a.lastMessageTime ?? DateTime(2000);
      final bt = b.lastMessageTime ?? DateTime(2000);
      return bt.compareTo(at);
    });
    return list;
  }

  Conversation? getConversationByPeer(String peerId) {
    try {
      return _conversationsBox.values.firstWhere((c) => c.peerId == peerId);
    } catch (_) {
      return null;
    }
  }

  // ── Messages ───────────────────────────────────────────
  Future<void> saveMessage(Message m) async {
    await _messagesBox.put(m.id, m);
    // Maintain the per-conversation index for O(k) lookups instead of O(n) scans.
    final ids = (_msgIndexBox.get(m.conversationId) as List?)?.cast<String>() ?? <String>[];
    if (!ids.contains(m.id)) {
      ids.add(m.id);
      await _msgIndexBox.put(m.conversationId, ids);
    }
  }

  Message? getMessage(String id) => _messagesBox.get(id);

  List<Message> getMessages(String conversationId) {
    final ids = (_msgIndexBox.get(conversationId) as List?)?.cast<String>();
    final List<Message> list;
    if (ids != null) {
      // Fast path: resolve just this conversation's messages via the index.
      list = [
        for (final id in ids)
          if (_messagesBox.get(id) != null) _messagesBox.get(id)!
      ];
    } else {
      // Fallback (e.g. legacy data written before the index existed).
      list = _messagesBox.values
          .where((m) => m.conversationId == conversationId)
          .toList();
    }
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  int getUnreadCount(String conversationId, String myId) {
    return _messagesBox.values
        .where((m) =>
            m.conversationId == conversationId &&
            m.senderId != myId &&
            !m.isRead)
        .length;
  }

  Future<void> markConversationRead(String conversationId, String myId) async {
    final unread = _messagesBox.values.where((m) =>
        m.conversationId == conversationId &&
        m.senderId != myId &&
        !m.isRead);
    for (final m in unread) {
      m.isRead = true;
      await m.save();
    }
  }

  // ── Posts ──────────────────────────────────────────────
  Future<void> savePost(Post p) => _postsBox.put(p.id, p);
  Post? getPost(String id) => _postsBox.get(id);

  /// Delete a post entirely (only the author should be offered this in the UI).
  Future<void> deletePost(String id) => _postsBox.delete(id);

  /// Posts the user chose to hide ("Not interested"). Stored locally; the post
  /// still exists on the author's device — we just stop showing it here.
  Set<String> get hiddenPostIds {
    final raw = _settingsBox.get('hidden_posts');
    if (raw is List) return raw.cast<String>().toSet();
    return {};
  }

  Future<void> hidePost(String id) async {
    final set = hiddenPostIds..add(id);
    await _settingsBox.put('hidden_posts', set.toList());
  }

  List<Post> get allPosts {
    final hidden = hiddenPostIds;
    final list = _postsBox.values.where((p) => !hidden.contains(p.id)).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  // ── Stories ────────────────────────────────────────────
  Future<void> saveStory(Story s) => _storiesBox.put(s.id, s);
  Story? getStory(String id) => _storiesBox.get(id);

  List<Story> get activeStories {
    final now = DateTime.now();
    return _storiesBox.values.where((s) => now.isBefore(s.expiresAt)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Grouped by author
  Map<String, List<Story>> get storiesByAuthor {
    final stories = activeStories;
    final map = <String, List<Story>>{};
    for (final s in stories) {
      map.putIfAbsent(s.authorId, () => []).add(s);
    }
    return map;
  }

  // ── Nearby Devices ─────────────────────────────────────
  Future<void> saveNearbyDevice(NearbyDevice d) => _nearbyBox.put(d.deviceId, d);
  Future<void> removeNearbyDevice(String id) => _nearbyBox.delete(id);
  Future<void> clearNearbyDevices() => _nearbyBox.clear();

  List<NearbyDevice> get nearbyDevices {
    final cutoff = DateTime.now().subtract(
        const Duration(seconds: AppConstants.nearbyTimeoutSeconds * 2));
    return _nearbyBox.values
        .where((d) => d.lastSeen.isAfter(cutoff))
        .toList()
      ..sort((a, b) => a.estimatedDistanceM.compareTo(b.estimatedDistanceM));
  }

  // ── Comments ───────────────────────────────────────────
  Future<void> saveComment(Comment c) => _commentsBox.put(c.id, c);

  List<Comment> getComments(String postId) {
    final list = _commentsBox.values.where((c) => c.postId == postId).toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  int getCommentCount(String postId) {
    return _commentsBox.values.where((c) => c.postId == postId).length;
  }

  // ── Queued Messages (store-and-forward) ────────────────
  Future<void> saveQueued(QueuedMessage q) => _queuedBox.put(q.messageId, q);
  Future<void> deleteQueued(String messageId) => _queuedBox.delete(messageId);
  QueuedMessage? getQueued(String messageId) => _queuedBox.get(messageId);

  List<QueuedMessage> get allQueued {
    final now = DateTime.now();
    return _queuedBox.values.where((q) => now.isBefore(q.expiresAt)).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  List<QueuedMessage> queuedFor(String recipientId) =>
      allQueued.where((q) => q.recipientId == recipientId).toList();

  Future<void> purgeExpiredQueued() async {
    final expired =
        _queuedBox.values.where((q) => q.isExpired).map((q) => q.messageId).toList();
    for (final id in expired) {
      await _queuedBox.delete(id);
    }
  }

  // ── Stats ─────────────────────────────────────────────
  int get totalMessagesSent => _messagesBox.values
      .where((m) => m.senderId == currentUser?.id)
      .length;

  int get totalConnections => _conversationsBox.values.length;

  // ── Bookmarks ─────────────────────────────────────────
  Set<String> get bookmarkedPostIds {
    final raw = _settingsBox.get('bookmarked_posts');
    if (raw is List) return raw.cast<String>().toSet();
    return {};
  }

  Future<void> toggleBookmark(String postId) async {
    final bookmarks = bookmarkedPostIds;
    if (bookmarks.contains(postId)) {
      bookmarks.remove(postId);
    } else {
      bookmarks.add(postId);
    }
    await _settingsBox.put('bookmarked_posts', bookmarks.toList());
  }

  bool isBookmarked(String postId) => bookmarkedPostIds.contains(postId);

  // ── Blocking / Safety ──────────────────────────────────
  Set<String> get blockedIds {
    final raw = _settingsBox.get('blocked_ids');
    if (raw is List) return raw.cast<String>().toSet();
    return {};
  }

  bool isBlocked(String peerId) => blockedIds.contains(peerId);

  Future<void> setBlocked(String peerId, bool blocked) async {
    final set = blockedIds;
    if (blocked) {
      set.add(peerId);
    } else {
      set.remove(peerId);
    }
    await _settingsBox.put('blocked_ids', set.toList());
  }

  Set<String> get mutedConversationIds {
    final raw = _settingsBox.get('muted_conversations');
    if (raw is List) return raw.cast<String>().toSet();
    return {};
  }

  bool isMuted(String conversationId) =>
      mutedConversationIds.contains(conversationId);

  Future<void> setMuted(String conversationId, bool muted) async {
    final set = mutedConversationIds;
    if (muted) {
      set.add(conversationId);
    } else {
      set.remove(conversationId);
    }
    await _settingsBox.put('muted_conversations', set.toList());
  }

  // ── Pinned peer keys (TOFU key pinning) ────────────────
  /// The public key we first verified for a peer endpoint. A later connection
  /// presenting a *different* key is a red flag (possible impersonation/MITM).
  String? pinnedKeyFor(String peerId) =>
      _settingsBox.get('pinned_key_$peerId') as String?;

  Future<void> pinKeyFor(String peerId, String publicKeyB64) =>
      _settingsBox.put('pinned_key_$peerId', publicKeyB64);

  /// Peer ids the user has manually confirmed via fingerprint comparison.
  Set<String> get verifiedPeerIds {
    final raw = _settingsBox.get('verified_peers');
    if (raw is List) return raw.cast<String>().toSet();
    return {};
  }

  bool isVerified(String peerId) => verifiedPeerIds.contains(peerId);

  Future<void> setVerified(String peerId, bool verified) async {
    final set = verifiedPeerIds;
    if (verified) {
      set.add(peerId);
    } else {
      set.remove(peerId);
    }
    await _settingsBox.put('verified_peers', set.toList());
  }

  // ── Drafts (unposted compositions) ─────────────────────
  /// Drafts live in the settings box as a list of maps:
  /// {id, text, mediaPath, createdAt}. Small, local-only, no schema migration.
  List<Map<String, dynamic>> get drafts {
    final raw = _settingsBox.get('post_drafts');
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList()
        ..sort((a, b) =>
            (b['createdAt'] as String? ?? '').compareTo(a['createdAt'] as String? ?? ''));
    }
    return [];
  }

  Future<void> saveDraft(Map<String, dynamic> draft) async {
    final list = drafts..removeWhere((d) => d['id'] == draft['id']);
    list.insert(0, draft);
    await _settingsBox.put('post_drafts', list);
  }

  Future<void> deleteDraft(String id) async {
    final list = drafts..removeWhere((d) => d['id'] == id);
    await _settingsBox.put('post_drafts', list);
  }

  // ── Shared posts (what I've sent to people nearby) ─────
  Set<String> get sharedPostIds {
    final raw = _settingsBox.get('shared_post_ids');
    if (raw is List) return raw.cast<String>().toSet();
    return {};
  }

  Future<void> recordShared(String postId) async {
    final set = sharedPostIds..add(postId);
    await _settingsBox.put('shared_post_ids', set.toList());
  }

  /// Posts I've shared with nearby people (kept even if hidden from Home).
  List<Post> get sharedPosts {
    final ids = sharedPostIds;
    final list = _postsBox.values.where((p) => ids.contains(p.id)).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  // ── Settings ───────────────────────────────────────────
  dynamic getSetting(String key) => _settingsBox.get(key);
  Future<void> setSetting(String key, dynamic value) => _settingsBox.put(key, value);
}
