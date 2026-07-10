/// Hive type adapters for BlueSnap models
/// In production, generate these with hive_generator.
/// Hand-written here for Phase 1 clarity.
library;

import 'package:hive/hive.dart';
import '../models/models.dart';

class UserAdapter extends TypeAdapter<User> {
  @override
  final int typeId = 0;

  @override
  User read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return User(
      id: fields[0] as String,
      displayName: fields[1] as String,
      bio: fields[2] as String?,
      avatarPath: fields[3] as String?,
      avatarColorIndex: fields[4] as int? ?? 0,
      publicKey: fields[5] as String? ?? '',
      createdAt: fields[6] as DateTime?,
      lastSeen: fields[7] as DateTime?,
      isCurrentUser: fields[8] as bool? ?? false,
      username: fields[9] as String?,
      followerCount: fields[10] as int? ?? 0,
      followingCount: fields[11] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, User obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.displayName)
      ..writeByte(2)..write(obj.bio)
      ..writeByte(3)..write(obj.avatarPath)
      ..writeByte(4)..write(obj.avatarColorIndex)
      ..writeByte(5)..write(obj.publicKey)
      ..writeByte(6)..write(obj.createdAt)
      ..writeByte(7)..write(obj.lastSeen)
      ..writeByte(8)..write(obj.isCurrentUser)
      ..writeByte(9)..write(obj.username)
      ..writeByte(10)..write(obj.followerCount)
      ..writeByte(11)..write(obj.followingCount);
  }
}

class MessageAdapter extends TypeAdapter<Message> {
  @override
  final int typeId = 1;

  @override
  Message read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Message(
      id: fields[0] as String,
      conversationId: fields[1] as String,
      senderId: fields[2] as String,
      receiverId: fields[3] as String,
      content: fields[4] as String,
      messageTypeIndex: fields[5] as int? ?? 0,
      statusIndex: fields[6] as int? ?? 0,
      transportTypeIndex: fields[7] as int? ?? 0,
      timestamp: fields[8] as DateTime?,
      mediaPath: fields[9] as String?,
      thumbnailPath: fields[10] as String?,
      mediaSizeBytes: fields[11] as int?,
      durationMs: fields[12] as int?,
      expiresAt: fields[13] as DateTime?,
      isRead: fields[14] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, Message obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.conversationId)
      ..writeByte(2)..write(obj.senderId)
      ..writeByte(3)..write(obj.receiverId)
      ..writeByte(4)..write(obj.content)
      ..writeByte(5)..write(obj.messageTypeIndex)
      ..writeByte(6)..write(obj.statusIndex)
      ..writeByte(7)..write(obj.transportTypeIndex)
      ..writeByte(8)..write(obj.timestamp)
      ..writeByte(9)..write(obj.mediaPath)
      ..writeByte(10)..write(obj.thumbnailPath)
      ..writeByte(11)..write(obj.mediaSizeBytes)
      ..writeByte(12)..write(obj.durationMs)
      ..writeByte(13)..write(obj.expiresAt)
      ..writeByte(14)..write(obj.isRead);
  }
}

class ConversationAdapter extends TypeAdapter<Conversation> {
  @override
  final int typeId = 2;

  @override
  Conversation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Conversation(
      id: fields[0] as String,
      peerId: fields[1] as String,
      peerName: fields[2] as String,
      peerAvatarColorIndex: fields[3] as int? ?? 0,
      lastMessage: fields[4] as String?,
      lastMessageTime: fields[5] as DateTime?,
      unreadCount: fields[6] as int? ?? 0,
      isPinned: fields[7] as bool? ?? false,
      lastTransportIndex: fields[8] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, Conversation obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.peerId)
      ..writeByte(2)..write(obj.peerName)
      ..writeByte(3)..write(obj.peerAvatarColorIndex)
      ..writeByte(4)..write(obj.lastMessage)
      ..writeByte(5)..write(obj.lastMessageTime)
      ..writeByte(6)..write(obj.unreadCount)
      ..writeByte(7)..write(obj.isPinned)
      ..writeByte(8)..write(obj.lastTransportIndex);
  }
}

class PostAdapter extends TypeAdapter<Post> {
  @override
  final int typeId = 3;

  @override
  Post read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Post(
      id: fields[0] as String,
      authorId: fields[1] as String,
      authorName: fields[2] as String,
      authorAvatarColorIndex: fields[3] as int? ?? 0,
      textContent: fields[4] as String?,
      mediaPath: fields[5] as String?,
      isVideo: fields[6] as bool? ?? false,
      createdAt: fields[7] as DateTime?,
      likeCount: fields[8] as int? ?? 0,
      commentCount: fields[9] as int? ?? 0,
      shareCount: fields[10] as int? ?? 0,
      isLikedByMe: fields[11] as bool? ?? false,
      distanceMeters: fields[12] as double? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, Post obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.authorId)
      ..writeByte(2)..write(obj.authorName)
      ..writeByte(3)..write(obj.authorAvatarColorIndex)
      ..writeByte(4)..write(obj.textContent)
      ..writeByte(5)..write(obj.mediaPath)
      ..writeByte(6)..write(obj.isVideo)
      ..writeByte(7)..write(obj.createdAt)
      ..writeByte(8)..write(obj.likeCount)
      ..writeByte(9)..write(obj.commentCount)
      ..writeByte(10)..write(obj.shareCount)
      ..writeByte(11)..write(obj.isLikedByMe)
      ..writeByte(12)..write(obj.distanceMeters);
  }
}

class StoryAdapter extends TypeAdapter<Story> {
  @override
  final int typeId = 4;

  @override
  Story read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Story(
      id: fields[0] as String,
      authorId: fields[1] as String,
      authorName: fields[2] as String,
      authorAvatarColorIndex: fields[3] as int? ?? 0,
      mediaPath: fields[4] as String?,
      textOverlay: fields[5] as String?,
      createdAt: fields[6] as DateTime?,
      expiresAt: fields[7] as DateTime?,
      isViewed: fields[8] as bool? ?? false,
      viewCount: fields[9] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, Story obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.authorId)
      ..writeByte(2)..write(obj.authorName)
      ..writeByte(3)..write(obj.authorAvatarColorIndex)
      ..writeByte(4)..write(obj.mediaPath)
      ..writeByte(5)..write(obj.textOverlay)
      ..writeByte(6)..write(obj.createdAt)
      ..writeByte(7)..write(obj.expiresAt)
      ..writeByte(8)..write(obj.isViewed)
      ..writeByte(9)..write(obj.viewCount);
  }
}

class NearbyDeviceAdapter extends TypeAdapter<NearbyDevice> {
  @override
  final int typeId = 5;

  @override
  NearbyDevice read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NearbyDevice(
      deviceId: fields[0] as String,
      userName: fields[1] as String,
      avatarColorIndex: fields[2] as int? ?? 0,
      rssi: fields[3] as int? ?? -60,
      estimatedDistanceM: fields[4] as double? ?? 10,
      connectionStateIndex: fields[5] as int? ?? 0,
      lastSeen: fields[6] as DateTime?,
      transportTypeIndex: fields[7] as int? ?? 0,
      bio: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, NearbyDevice obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)..write(obj.deviceId)
      ..writeByte(1)..write(obj.userName)
      ..writeByte(2)..write(obj.avatarColorIndex)
      ..writeByte(3)..write(obj.rssi)
      ..writeByte(4)..write(obj.estimatedDistanceM)
      ..writeByte(5)..write(obj.connectionStateIndex)
      ..writeByte(6)..write(obj.lastSeen)
      ..writeByte(7)..write(obj.transportTypeIndex)
      ..writeByte(8)..write(obj.bio);
  }
}

class CommentAdapter extends TypeAdapter<Comment> {
  @override
  final int typeId = 6;

  @override
  Comment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Comment(
      id: fields[0] as String,
      postId: fields[1] as String,
      authorId: fields[2] as String,
      authorName: fields[3] as String,
      authorAvatarColorIndex: fields[4] as int? ?? 0,
      content: fields[5] as String,
      createdAt: fields[6] as DateTime?,
      likeCount: fields[7] as int? ?? 0,
      isLikedByMe: fields[8] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, Comment obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.postId)
      ..writeByte(2)..write(obj.authorId)
      ..writeByte(3)..write(obj.authorName)
      ..writeByte(4)..write(obj.authorAvatarColorIndex)
      ..writeByte(5)..write(obj.content)
      ..writeByte(6)..write(obj.createdAt)
      ..writeByte(7)..write(obj.likeCount)
      ..writeByte(8)..write(obj.isLikedByMe);
  }
}

class QueuedMessageAdapter extends TypeAdapter<QueuedMessage> {
  @override
  final int typeId = 7;

  @override
  QueuedMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QueuedMessage(
      messageId: fields[0] as String,
      recipientId: fields[1] as String,
      content: fields[2] as String,
      createdAt: fields[3] as DateTime?,
      attempts: fields[4] as int? ?? 0,
      lastAttempt: fields[5] as DateTime?,
      expiresAt: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, QueuedMessage obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)..write(obj.messageId)
      ..writeByte(1)..write(obj.recipientId)
      ..writeByte(2)..write(obj.content)
      ..writeByte(3)..write(obj.createdAt)
      ..writeByte(4)..write(obj.attempts)
      ..writeByte(5)..write(obj.lastAttempt)
      ..writeByte(6)..write(obj.expiresAt);
  }
}

/// Register all adapters
void registerAdapters() {
  Hive.registerAdapter(UserAdapter());
  Hive.registerAdapter(MessageAdapter());
  Hive.registerAdapter(ConversationAdapter());
  Hive.registerAdapter(PostAdapter());
  Hive.registerAdapter(StoryAdapter());
  Hive.registerAdapter(NearbyDeviceAdapter());
  Hive.registerAdapter(CommentAdapter());
  Hive.registerAdapter(QueuedMessageAdapter());
}
