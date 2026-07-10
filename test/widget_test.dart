// Smoke test for the BlueSnap binary protocol and presence payload.
//
// The original template test referenced a non-existent `MyApp`; it has been
// replaced with real, device-free tests that exercise the wire format.

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:bluesnap/data/protocol/bluetooth_protocol.dart';

void main() {
  group('BlueSnapProtocol', () {
    test('encodes and decodes a text message round-trip', () {
      final packet = BlueSnapProtocol.encodeMessage(
        senderId: 'user-aaaa',
        receiverId: 'user-bbbb',
        messageId: 'msg-1',
        content: 'Hello over Bluetooth',
      );

      final decoded = BlueSnapProtocol.decode(packet);
      expect(decoded, isNotNull);
      expect(decoded!['type'], PacketType.message);
      expect(decoded['senderId'], 'user-aaaa');
      expect((decoded['payload'] as Map)['t'], 'Hello over Bluetooth');
    });

    test('rejects a packet with a corrupted CRC', () {
      final packet = BlueSnapProtocol.encodeMessage(
        senderId: 'user-aaaa',
        receiverId: 'user-bbbb',
        messageId: 'msg-1',
        content: 'tamper me',
      );
      packet[packet.length - 1] ^= 0xFF; // flip a CRC byte
      expect(BlueSnapProtocol.decode(packet), isNull);
    });
  });

  group('PresencePayload', () {
    test('round-trips name and color index', () {
      const p = PresencePayload(displayName: 'Alice', avatarColorIndex: 3);
      final decoded = PresencePayload.decode(p.encode());
      expect(decoded.displayName, 'Alice');
      expect(decoded.avatarColorIndex, 3);
    });

    test('throws on truncated input', () {
      expect(
        () => PresencePayload.decode(Uint8List.fromList([10, 65])),
        throwsFormatException,
      );
    });
  });
}
