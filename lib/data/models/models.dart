/// BlueSnap data models
library;

import 'package:hive/hive.dart';

// ══════════════════════════════════════════════════════════
// USER
// ══════════════════════════════════════════════════════════
@HiveType(typeId: 0)
class User extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String displayName;

  @HiveField(2)
  String? bio;

  @HiveField(3)
  String? avatarPath;

  @HiveField(4)
  int avatarColorIndex;

  @HiveField(5)
  String publicKey;

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  DateTime lastSeen;

  @HiveField(8)
  bool isCurrentUser;

  @HiveField(9)
  String? username;

  @HiveField(10)
  int followerCount;

  @HiveField(11)
  int followingCount;

  User({
    required this.id,
    required this.displayName,
    this.bio,
    this.avatarPath,
    this.avatarColorIndex = 0,
    this.publicKey = '',
    DateTime? createdAt,
    DateTime? lastSeen,
    this.isCurrentUser = false,
    this.username,
    this.followerCount = 0,
    this.followingCount = 0,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastSeen = lastSeen ?? DateTime.now();

  String get initials {
    final parts = displayName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return displayName.substring(0, displayName.length >= 2 ? 2 : 1).toUpperCase();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'bio': bio,
        'avatarColorIndex': avatarColorIndex,
        'publicKey': publicKey,
        'username': username,
        'followerCount': followerCount,
        'followingCount': followingCount,
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        bio: json['bio'] as String?,
        avatarColorIndex: json['avatarColorIndex'] as int? ?? 0,
        publicKey: json['publicKey'] as String? ?? '',
        username: json['username'] as String?,
        followerCount: json['followerCount'] as int? ?? 0,
        followingCount: json['followingCount'] as int? ?? 0,
      );
}

// ══════════════════════════════════════════════════════════
// MESSAGE
// ══════════════════════════════════════════════════════════
// NOTE: append-only — these are persisted by index. Never reorder or remove.
enum MessageType { text, image, video, voice, snap, system, file }
enum MessageStatus { sending, sent, delivered, read, failed }
enum TransportType { ble, classic, wifiDirect, mesh }

@HiveType(typeId: 1)
class Message extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String conversationId;

  @HiveField(2)
  final String senderId;

  @HiveField(3)
  final String receiverId;

  @HiveField(4)
  String content;

  @HiveField(5)
  int messageTypeIndex; // MessageType index

  @HiveField(6)
  int statusIndex; // MessageStatus index

  @HiveField(7)
  int transportTypeIndex; // TransportType index

  @HiveField(8)
  DateTime timestamp;

  @HiveField(9)
  String? mediaPath;

  @HiveField(10)
  String? thumbnailPath;

  @HiveField(11)
  int? mediaSizeBytes;

  @HiveField(12)
  int? durationMs;

  @HiveField(13)
  DateTime? expiresAt;

  @HiveField(14)
  bool isRead;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.messageTypeIndex = 0,
    this.statusIndex = 0,
    this.transportTypeIndex = 0,
    DateTime? timestamp,
    this.mediaPath,
    this.thumbnailPath,
    this.mediaSizeBytes,
    this.durationMs,
    this.expiresAt,
    this.isRead = false,
  }) : timestamp = timestamp ?? DateTime.now();

  MessageType get messageType => MessageType.values[messageTypeIndex];
  set messageType(MessageType t) => messageTypeIndex = t.index;

  MessageStatus get status => MessageStatus.values[statusIndex];
  set status(MessageStatus s) => statusIndex = s.index;

  TransportType get transportType => TransportType.values[transportTypeIndex];
  set transportType(TransportType t) => transportTypeIndex = t.index;

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);
}

// ══════════════════════════════════════════════════════════
// CONVERSATION
// ══════════════════════════════════════════════════════════
@HiveType(typeId: 2)
class Conversation extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String peerId;

  @HiveField(2)
  String peerName;

  @HiveField(3)
  int peerAvatarColorIndex;

  @HiveField(4)
  String? lastMessage;

  @HiveField(5)
  DateTime? lastMessageTime;

  @HiveField(6)
  int unreadCount;

  @HiveField(7)
  bool isPinned;

  @HiveField(8)
  int lastTransportIndex;

  Conversation({
    required this.id,
    required this.peerId,
    required this.peerName,
    this.peerAvatarColorIndex = 0,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isPinned = false,
    this.lastTransportIndex = 0,
  });

  TransportType get lastTransport => TransportType.values[lastTransportIndex];
}

// ══════════════════════════════════════════════════════════
// POST (Feed)
// ══════════════════════════════════════════════════════════
@HiveType(typeId: 3)
class Post extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String authorId;

  @HiveField(2)
  String authorName;

  @HiveField(3)
  int authorAvatarColorIndex;

  @HiveField(4)
  String? textContent;

  @HiveField(5)
  String? mediaPath;

  @HiveField(6)
  bool isVideo;

  @HiveField(7)
  DateTime createdAt;

  @HiveField(8)
  int likeCount;

  @HiveField(9)
  int commentCount;

  @HiveField(10)
  int shareCount;

  @HiveField(11)
  bool isLikedByMe;

  @HiveField(12)
  double distanceMeters;

  Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatarColorIndex = 0,
    this.textContent,
    this.mediaPath,
    this.isVideo = false,
    DateTime? createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.isLikedByMe = false,
    this.distanceMeters = 0,
  }) : createdAt = createdAt ?? DateTime.now();
}

// ══════════════════════════════════════════════════════════
// STORY
// ══════════════════════════════════════════════════════════
@HiveType(typeId: 4)
class Story extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String authorId;

  @HiveField(2)
  String authorName;

  @HiveField(3)
  int authorAvatarColorIndex;

  @HiveField(4)
  String? mediaPath;

  @HiveField(5)
  String? textOverlay;

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  DateTime expiresAt;

  @HiveField(8)
  bool isViewed;

  @HiveField(9)
  int viewCount;

  Story({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatarColorIndex = 0,
    this.mediaPath,
    this.textOverlay,
    DateTime? createdAt,
    DateTime? expiresAt,
    this.isViewed = false,
    this.viewCount = 0,
  })  : createdAt = createdAt ?? DateTime.now(),
        expiresAt =
            expiresAt ?? DateTime.now().add(const Duration(hours: 24));

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

// ══════════════════════════════════════════════════════════
// COMMENT
// ══════════════════════════════════════════════════════════
@HiveType(typeId: 6)
class Comment extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String postId;

  @HiveField(2)
  final String authorId;

  @HiveField(3)
  String authorName;

  @HiveField(4)
  int authorAvatarColorIndex;

  @HiveField(5)
  String content;

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  int likeCount;

  @HiveField(8)
  bool isLikedByMe;

  Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    this.authorAvatarColorIndex = 0,
    required this.content,
    DateTime? createdAt,
    this.likeCount = 0,
    this.isLikedByMe = false,
  }) : createdAt = createdAt ?? DateTime.now();
}

// ══════════════════════════════════════════════════════════
// NEARBY DEVICE (Radar)
// ══════════════════════════════════════════════════════════
enum ConnectionState { discovered, connecting, connected, disconnected }

@HiveType(typeId: 5)
class NearbyDevice extends HiveObject {
  @HiveField(0)
  final String deviceId;

  @HiveField(1)
  String userName;

  @HiveField(2)
  int avatarColorIndex;

  @HiveField(3)
  int rssi; // signal strength (negative dBm)

  @HiveField(4)
  double estimatedDistanceM;

  @HiveField(5)
  int connectionStateIndex;

  @HiveField(6)
  DateTime lastSeen;

  @HiveField(7)
  int transportTypeIndex;

  @HiveField(8)
  String? bio;

  NearbyDevice({
    required this.deviceId,
    required this.userName,
    this.avatarColorIndex = 0,
    this.rssi = -60,
    this.estimatedDistanceM = 10,
    this.connectionStateIndex = 0,
    DateTime? lastSeen,
    this.transportTypeIndex = 0,
    this.bio,
  }) : lastSeen = lastSeen ?? DateTime.now();

  ConnectionState get connectionState =>
      ConnectionState.values[connectionStateIndex];
  TransportType get transportType => TransportType.values[transportTypeIndex];

  /// Rough signal quality 0.0 - 1.0
  double get signalQuality {
    // RSSI typically ranges from -30 (very close) to -100 (far)
    return ((rssi + 100) / 70).clamp(0.0, 1.0);
  }

  String get distanceLabel {
    if (estimatedDistanceM < 1) return '<1m';
    if (estimatedDistanceM < 10) return '${estimatedDistanceM.toInt()}m';
    if (estimatedDistanceM < 100) return '~${estimatedDistanceM.toInt()}m';
    return '${(estimatedDistanceM / 100).toStringAsFixed(1)}00m+';
  }
}

// ══════════════════════════════════════════════════════════
// QUEUED MESSAGE (store-and-forward)
// ══════════════════════════════════════════════════════════
/// A message waiting to be delivered once the recipient is in range again.
/// Keyed by [messageId] so retries are idempotent end-to-end.
@HiveType(typeId: 7)
class QueuedMessage extends HiveObject {
  @HiveField(0)
  final String messageId;

  @HiveField(1)
  final String recipientId;

  @HiveField(2)
  final String content;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  int attempts;

  @HiveField(5)
  DateTime? lastAttempt;

  @HiveField(6)
  DateTime expiresAt;

  QueuedMessage({
    required this.messageId,
    required this.recipientId,
    required this.content,
    DateTime? createdAt,
    this.attempts = 0,
    this.lastAttempt,
    DateTime? expiresAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        expiresAt = expiresAt ?? DateTime.now().add(const Duration(days: 7));

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
