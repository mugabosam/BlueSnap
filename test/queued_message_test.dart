// Tests the store-and-forward QueuedMessage model's TTL behaviour.

import 'package:bluesnap/data/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QueuedMessage', () {
    test('defaults to a 7-day expiry and is not expired when fresh', () {
      final q = QueuedMessage(
        messageId: 'm1',
        recipientId: 'peer-1',
        content: 'hello',
      );
      expect(q.isExpired, isFalse);
      final ttl = q.expiresAt.difference(q.createdAt).inDays;
      expect(ttl, 7);
      expect(q.attempts, 0);
    });

    test('reports expired once past expiresAt', () {
      final q = QueuedMessage(
        messageId: 'm2',
        recipientId: 'peer-1',
        content: 'old',
        createdAt: DateTime.now().subtract(const Duration(days: 8)),
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(q.isExpired, isTrue);
    });
  });
}
