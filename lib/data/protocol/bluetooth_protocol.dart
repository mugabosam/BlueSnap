/// BlueSnap Protocol — binary packet encoder/decoder for BT communication
///
/// Packet Structure:
/// [Magic 2B][Version 1B][Type 1B][SenderID 16B][ReceiverID 16B][Timestamp 8B][Payload varB][CRC 4B]
import 'dart:typed_data';
import 'dart:convert';

enum PacketType {
  presence,     // 0x00 — BLE advertising: "I'm here"
  message,      // 0x01 — Text message
  mediaHeader,  // 0x02 — File transfer header
  mediaChunk,   // 0x03 — File chunk data
  mediaAck,     // 0x04 — Chunk received ack
  callRequest,  // 0x05 — Call initiation
  callAccept,   // 0x06
  callReject,   // 0x07
  callEnd,      // 0x08
  ping,         // 0x09
  pong,         // 0x0A
  meshRelay,    // 0x0B — Wraps another packet for mesh forwarding
}

class BlueSnapProtocol {
  static const int magicByte1 = 0xB5;
  static const int magicByte2 = 0xAA;
  static const int protocolVersion = 1;
  static const int headerSize = 44;

  /// Encode a presence broadcast packet
  static Uint8List encodePresence({
    required String senderId,
    required String displayName,
    required int avatarColorIndex,
  }) {
    final payload = utf8.encode(json.encode({
      'n': displayName,
      'c': avatarColorIndex,
    }));
    return _buildPacket(PacketType.presence, senderId, '', payload);
  }

  /// Encode a text message
  static Uint8List encodeMessage({
    required String senderId,
    required String receiverId,
    required String messageId,
    required String content,
  }) {
    final payload = utf8.encode(json.encode({
      'id': messageId,
      't': content,
    }));
    return _buildPacket(PacketType.message, senderId, receiverId, payload);
  }

  /// Encode a file transfer header
  static Uint8List encodeMediaHeader({
    required String senderId,
    required String receiverId,
    required String fileId,
    required String fileName,
    required int totalBytes,
    required int totalChunks,
    required String mimeType,
  }) {
    final payload = utf8.encode(json.encode({
      'fid': fileId,
      'fn': fileName,
      'sz': totalBytes,
      'ch': totalChunks,
      'mt': mimeType,
    }));
    return _buildPacket(PacketType.mediaHeader, senderId, receiverId, payload);
  }

  /// Encode a file chunk
  static Uint8List encodeMediaChunk({
    required String senderId,
    required String receiverId,
    required String fileId,
    required int chunkIndex,
    required Uint8List chunkData,
  }) {
    final prefix = utf8.encode('$fileId:$chunkIndex:');
    final payload = Uint8List(prefix.length + chunkData.length)
      ..setAll(0, prefix)
      ..setAll(prefix.length, chunkData);
    return _buildPacket(PacketType.mediaChunk, senderId, receiverId, payload);
  }

  /// Decode a received packet
  static Map<String, dynamic>? decode(Uint8List data) {
    if (data.length < headerSize + 4) return null;
    if (data[0] != magicByte1 || data[1] != magicByte2) return null;
    if (data[2] != protocolVersion) return null;

    final typeIndex = data[3];
    if (typeIndex >= PacketType.values.length) return null;

    final senderId = String.fromCharCodes(data.sublist(4, 20)).trim();
    final receiverId = String.fromCharCodes(data.sublist(20, 36)).trim();
    final timestamp = DateTime.fromMillisecondsSinceEpoch(
      data.buffer.asByteData(36, 8).getInt64(0),
    );

    final payloadBytes = data.sublist(headerSize, data.length - 4);

    // CRC verification
    final expectedCrc = data.buffer.asByteData(data.length - 4, 4).getUint32(0);
    if (_crc32(data.sublist(0, data.length - 4)) != expectedCrc) return null;

    final type = PacketType.values[typeIndex];
    dynamic payload;
    if (type == PacketType.mediaChunk) {
      payload = payloadBytes;
    } else {
      try {
        payload = json.decode(utf8.decode(payloadBytes));
      } catch (_) {
        payload = utf8.decode(payloadBytes, allowMalformed: true);
      }
    }

    return {
      'type': type,
      'senderId': senderId,
      'receiverId': receiverId,
      'timestamp': timestamp,
      'payload': payload,
    };
  }

  // ── Internal helpers ───────────────────────────────────

  static Uint8List _buildPacket(
    PacketType type, String senderId, String receiverId, List<int> payload,
  ) {
    final total = headerSize + payload.length + 4;
    final bytes = Uint8List(total);
    final bd = ByteData.view(bytes.buffer);

    bytes[0] = magicByte1;
    bytes[1] = magicByte2;
    bytes[2] = protocolVersion;
    bytes[3] = type.index;

    bytes.setRange(4, 20, utf8.encode(senderId.padRight(16).substring(0, 16)));
    bytes.setRange(20, 36, utf8.encode(receiverId.padRight(16).substring(0, 16)));
    bd.setInt64(36, DateTime.now().millisecondsSinceEpoch);
    bytes.setRange(headerSize, headerSize + payload.length, payload);
    bd.setUint32(total - 4, _crc32(bytes.sublist(0, total - 4)));

    return bytes;
  }

  static int _crc32(Uint8List data) {
    int crc = 0xFFFFFFFF;
    for (final b in data) {
      crc ^= b;
      for (int j = 0; j < 8; j++) {
        crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
      }
    }
    return crc ^ 0xFFFFFFFF;
  }
}

/// Compact presence payload carried in BLE advertising manufacturer data.
///
/// Layout: [nameLen 1B][name UTF-8 nameLen B][colorIndex 1B]
/// Kept tiny because BLE advertising manufacturer data is limited (~23 bytes).
class PresencePayload {
  final String displayName;
  final int avatarColorIndex;

  const PresencePayload({
    required this.displayName,
    required this.avatarColorIndex,
  });

  /// Encode to bytes for advertising. Name is truncated to fit BLE limits.
  Uint8List encode() {
    final nameBytes = utf8.encode(displayName);
    final clipped = nameBytes.length > 20 ? nameBytes.sublist(0, 20) : nameBytes;
    final out = Uint8List(2 + clipped.length);
    out[0] = clipped.length;
    out.setRange(1, 1 + clipped.length, clipped);
    out[1 + clipped.length] = avatarColorIndex & 0xFF;
    return out;
  }

  /// Decode from advertising bytes. Throws [FormatException] on malformed input.
  static PresencePayload decode(Uint8List data) {
    if (data.isEmpty) throw const FormatException('Empty presence payload');
    final nameLen = data[0];
    if (data.length < 2 + nameLen) {
      throw const FormatException('Truncated presence payload');
    }
    final name = utf8.decode(data.sublist(1, 1 + nameLen));
    final colorIndex = data[1 + nameLen];
    return PresencePayload(displayName: name, avatarColorIndex: colorIndex);
  }
}
