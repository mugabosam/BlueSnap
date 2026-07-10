/// BlueSnap store-and-forward queue.
///
/// When a recipient is out of range, outgoing messages are persisted here and
/// retried automatically the next time that peer connects (see NearbyService's
/// key-exchange handler). Entries are keyed by the stable message id so a
/// retry can never create a duplicate on the receiving side.
library;

import 'package:flutter/foundation.dart';
import '../data/database/database_service.dart';
import '../data/models/models.dart';

class MessageQueueService {
  static final MessageQueueService _instance = MessageQueueService._();
  factory MessageQueueService() => _instance;
  MessageQueueService._();

  final DatabaseService _db = DatabaseService();

  /// Persist an outgoing message for later delivery (idempotent on messageId).
  Future<void> enqueue({
    required String messageId,
    required String recipientId,
    required String content,
  }) async {
    if (_db.getQueued(messageId) != null) return;
    await _db.saveQueued(QueuedMessage(
      messageId: messageId,
      recipientId: recipientId,
      content: content,
    ));
    debugPrint('[Queue] Queued $messageId for $recipientId');
  }

  /// Non-expired messages waiting for [recipientId], oldest first.
  List<QueuedMessage> pendingFor(String recipientId) =>
      _db.queuedFor(recipientId);

  /// Count of all pending (non-expired) messages.
  int get pendingCount => _db.allQueued.length;

  /// Record a delivery attempt (does not remove the entry).
  Future<void> markAttempt(String messageId) async {
    final q = _db.getQueued(messageId);
    if (q == null) return;
    q.attempts += 1;
    q.lastAttempt = DateTime.now();
    await q.save();
  }

  /// Remove a delivered message from the queue.
  Future<void> remove(String messageId) => _db.deleteQueued(messageId);

  /// Drop messages older than their expiry (called periodically / on startup).
  Future<void> purgeExpired() => _db.purgeExpiredQueued();
}
