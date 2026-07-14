/// BlueSnap Nearby Connections Service
/// Uses Google's Nearby Connections API for real phone-to-phone
/// discovery and data exchange over BLE + Wi-Fi Direct.
///
/// This is the FASTEST path to two phones actually communicating:
/// - Handles BLE advertising + scanning automatically
/// - Upgrades to Wi-Fi Direct for large transfers automatically
/// - Works cross-device on all Android phones
/// - No GATT server code needed
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../data/models/models.dart';
import '../data/database/database_service.dart';
import '../core/constants.dart';
import 'crypto_service.dart';
import 'message_queue_service.dart';
import 'notification_service.dart';
import 'streak_service.dart';

enum NearbyState { idle, advertising, discovering, connected, error }

class NearbyService extends ChangeNotifier {
  static final NearbyService _instance = NearbyService._();
  factory NearbyService() => _instance;
  NearbyService._();

  final DatabaseService _db = DatabaseService();
  final CryptoService _crypto = CryptoService();
  final MessageQueueService _queue = MessageQueueService();
  final _uuid = const Uuid();
  final Nearby _nearby = Nearby();

  /// Peer public keys learned via key-exchange, keyed by endpointId.
  final Map<String, String> _peerKeys = {};

  static const String _serviceId = 'com.bluesnap.app';

  NearbyState _state = NearbyState.idle;
  NearbyState get state => _state;

  // My info (set during init)
  String _myName = 'BlueSnap User';
  String _myId = '';

  // Discovered endpoints: endpointId -> NearbyDevice
  final Map<String, NearbyDevice> _discoveredEndpoints = {};
  List<NearbyDevice> get discoveredDevices => _discoveredEndpoints.values.toList();

  // Connected endpoints
  final Map<String, String> _connectedEndpoints = {}; // endpointId -> userName
  bool get hasConnections => _connectedEndpoints.isNotEmpty;

  // Streams
  final _deviceDiscoveredController = StreamController<NearbyDevice>.broadcast();
  Stream<NearbyDevice> get onDeviceDiscovered => _deviceDiscoveredController.stream;

  final _deviceLostController = StreamController<String>.broadcast();
  Stream<String> get onDeviceLost => _deviceLostController.stream;

  final _messageReceivedController = StreamController<({String endpointId, String message})>.broadcast();
  Stream<({String endpointId, String message})> get onMessageReceived =>
      _messageReceivedController.stream;

  final _connectionController = StreamController<({String endpointId, String name, bool connected})>.broadcast();
  Stream<({String endpointId, String name, bool connected})> get onConnectionChanged =>
      _connectionController.stream;

  final _fileReceivedController = StreamController<({String endpointId, Uint8List data})>.broadcast();
  Stream<({String endpointId, Uint8List data})> get onFileReceived =>
      _fileReceivedController.stream;

  /// A fully-received media file that has been saved and persisted as a Message.
  final _mediaReceivedController =
      StreamController<({String endpointId, String conversationId})>.broadcast();
  Stream<({String endpointId, String conversationId})> get onMediaReceived =>
      _mediaReceivedController.stream;

  /// A new feed post or story received from a peer.
  final _feedController = StreamController<String>.broadcast();
  Stream<String> get onFeedUpdated => _feedController.stream;

  /// Metadata for an inbound file, awaiting the FILE payload (keyed by sender).
  final Map<String, List<Map<String, dynamic>>> _pendingFileMeta = {};

  /// In-flight inbound FILE payloads, keyed by Nearby payload id.
  final Map<int, Payload> _incomingFiles = {};

  final _typingController =
      StreamController<({String endpointId, bool isTyping})>.broadcast();
  Stream<({String endpointId, bool isTyping})> get onTypingChanged =>
      _typingController.stream;

  /// A connection is proposed by a peer and awaiting the user's accept/reject.
  /// Carries the Nearby authentication token for out-of-band verification.
  final _pendingConnectionController = StreamController<
      ({String endpointId, String name, String authToken})>.broadcast();
  Stream<({String endpointId, String name, String authToken})>
      get onConnectionPending => _pendingConnectionController.stream;

  /// Fired when a peer reconnects with a public key different from the one we
  /// pinned on first contact — a possible impersonation/MITM attempt.
  final _keyMismatchController =
      StreamController<({String endpointId, String name})>.broadcast();
  Stream<({String endpointId, String name})> get onKeyMismatch =>
      _keyMismatchController.stream;

  /// Endpoints whose incoming connection the user has approved.
  final Set<String> _approvedEndpoints = {};

  /// Per-endpoint callbacks captured at connection-initiation time.
  final Map<String, ConnectionInfo> _pendingInfos = {};

  /// Simple rate limiter: reject peers that flood us with messages.
  final Map<String, List<DateTime>> _msgTimestamps = {};
  static const _rateWindow = Duration(seconds: 10);
  static const _rateMaxInWindow = 30;

  // ── Initialization ───────────────────────────────────
  Future<void> init({required String userName, required String userId}) async {
    _myName = userName;
    _myId = userId;
  }

  // ── Start Advertising (Make yourself visible) ────────
  /// Call this when the app opens. Other BlueSnap users will find you.
  Future<bool> startAdvertising() async {
    try {
      debugPrint('[Nearby] Starting advertising as "$_myName"...');
      
      final result = await _nearby.startAdvertising(
        _myName,
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: _serviceId,
      );

      if (result) {
        _state = NearbyState.advertising;
        notifyListeners();
        debugPrint('[Nearby] Advertising started as "$_myName"');
      }
      return result;
    } catch (e) {
      debugPrint('[Nearby] Advertising failed: $e');
      _state = NearbyState.error;
      notifyListeners();
      return false;
    }
  }

  // ── Start Discovery (Find nearby users) ──────────────
  /// Scans for other BlueSnap users advertising nearby.
  Future<bool> startDiscovery() async {
    try {
      debugPrint('[Nearby] Starting discovery...');
      
      final result = await _nearby.startDiscovery(
        _myName,
        Strategy.P2P_CLUSTER,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLost,
        serviceId: _serviceId,
      );

      if (result) {
        _state = NearbyState.discovering;
        notifyListeners();
        debugPrint('[Nearby] Discovery started');
      }
      return result;
    } catch (e) {
      debugPrint('[Nearby] Discovery failed: $e');
      _state = NearbyState.error;
      notifyListeners();
      return false;
    }
  }

  /// Start both advertising AND discovering simultaneously.
  /// This is the recommended mode — you're visible AND scanning.
  Future<void> startBoth() async {
    debugPrint('[Nearby] 🚀 Starting BOTH advertising and discovery...');
    debugPrint('[Nearby] My name: $_myName');
    debugPrint('[Nearby] My ID: $_myId');
    debugPrint('[Nearby] Service ID: $_serviceId');
    
    final advResult = await startAdvertising();
    debugPrint('[Nearby] Advertising result: $advResult');
    
    final discResult = await startDiscovery();
    debugPrint('[Nearby] Discovery result: $discResult');
    
    if (advResult && discResult) {
      debugPrint('[Nearby] ✅ SUCCESS: Both advertising AND discovering active!');
      debugPrint('[Nearby] 📡 Now visible to other devices AND scanning for them');
      debugPrint('[Nearby] ⏰ Discovery may take 5-30 seconds...');
    } else {
      debugPrint('[Nearby] ❌ FAILED: Advertising=$advResult, Discovery=$discResult');
      debugPrint('[Nearby] 💡 Check permissions and Bluetooth/Location are enabled');
    }
  }

  // ── Stop Everything ──────────────────────────────────
  Future<void> stopAdvertising() async {
    await _nearby.stopAdvertising();
    debugPrint('[Nearby] Advertising stopped');
  }

  Future<void> stopDiscovery() async {
    await _nearby.stopDiscovery();
    _state = NearbyState.idle;
    notifyListeners();
    debugPrint('[Nearby] Discovery stopped');
  }

  Future<void> stopAll() async {
    await stopAdvertising();
    await stopDiscovery();
    _state = NearbyState.idle;
    notifyListeners();
  }

  // ── Connection Callbacks ─────────────────────────────
  void _onEndpointFound(String endpointId, String endpointName, String serviceId) {
    debugPrint('[Nearby] 🎉 DEVICE FOUND!');
    debugPrint('[Nearby]   Name: $endpointName');
    debugPrint('[Nearby]   Endpoint ID: $endpointId');
    debugPrint('[Nearby]   Service ID: $serviceId');

    final device = NearbyDevice(
      deviceId: endpointId,
      userName: endpointName,
      avatarColorIndex: endpointName.hashCode.abs() % AvatarColors.palette.length,
      rssi: -50, // Nearby API doesn't give RSSI, estimate
      estimatedDistanceM: 15, // Default estimate
      connectionStateIndex: ConnectionState.discovered.index,
      transportTypeIndex: TransportType.ble.index,
      bio: 'Discovered via Nearby',
    );

    _discoveredEndpoints[endpointId] = device;
    _db.saveNearbyDevice(device);
    _deviceDiscoveredController.add(device);
    notifyListeners();
  }

  void _onEndpointLost(String? endpointId) {
    if (endpointId == null) return;
    debugPrint('[Nearby] Lost: $endpointId');

    _discoveredEndpoints.remove(endpointId);
    _deviceLostController.add(endpointId);
    notifyListeners();
  }

  void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
    debugPrint('[Nearby] Connection initiated with ${info.endpointName} ($endpointId)');
    _pendingInfos[endpointId] = info;

    final device = _discoveredEndpoints[endpointId];
    if (device != null) {
      device.connectionStateIndex = ConnectionState.connecting.index;
      notifyListeners();
    }

    // If the user started this connection (outgoing) it's implicitly approved.
    // Otherwise surface it for an explicit accept/reject decision, carrying the
    // Nearby authentication token so both users can verify out-of-band.
    if (_approvedEndpoints.contains(endpointId)) {
      _acceptConnectionInternal(endpointId);
    } else {
      _pendingConnectionController.add((
        endpointId: endpointId,
        name: info.endpointName,
        authToken: info.authenticationToken,
      ));
    }
  }

  /// Approve an incoming connection request (called from the UI dialog).
  void acceptIncomingConnection(String endpointId) {
    _approvedEndpoints.add(endpointId);
    _acceptConnectionInternal(endpointId);
  }

  /// Refuse and drop an incoming connection request.
  Future<void> rejectIncomingConnection(String endpointId) async {
    _pendingInfos.remove(endpointId);
    try {
      await _nearby.rejectConnection(endpointId);
    } catch (_) {/* best effort */}
  }

  void _acceptConnectionInternal(String endpointId) {
    _nearby.acceptConnection(
      endpointId,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: _onPayloadTransferUpdate,
    );
  }

  void _onConnectionResult(String endpointId, Status status) {
    debugPrint('[Nearby] Connection result for $endpointId: ${status.toString()}');

    if (status == Status.CONNECTED) {
      final device = _discoveredEndpoints[endpointId];
      final name = device?.userName ?? 'Unknown';

      _connectedEndpoints[endpointId] = name;

      if (device != null) {
        device.connectionStateIndex = ConnectionState.connected.index;
        device.transportTypeIndex = TransportType.ble.index;
      }

      _state = NearbyState.connected;
      _connectionController.add((
        endpointId: endpointId,
        name: name,
        connected: true,
      ));

      // Run the authenticated ephemeral handshake so this session is
      // end-to-end encrypted AND forward-secret.
      _sendKeyExchange(endpointId);

      debugPrint('[Nearby] Connected to $name ($endpointId)');
    } else {
      final device = _discoveredEndpoints[endpointId];
      if (device != null) {
        device.connectionStateIndex = ConnectionState.disconnected.index;
      }
      debugPrint('[Nearby] Connection failed: $status');
    }

    notifyListeners();
  }

  void _onDisconnected(String endpointId) {
    debugPrint('[Nearby] Disconnected: $endpointId');

    final name = _connectedEndpoints.remove(endpointId);
    final device = _discoveredEndpoints[endpointId];
    if (device != null) {
      device.connectionStateIndex = ConnectionState.disconnected.index;
    }

    _connectionController.add((
      endpointId: endpointId,
      name: name ?? 'Unknown',
      connected: false,
    ));

    // Wipe the session's ephemeral + derived keys so past traffic in this
    // session can never be decrypted again (forward secrecy).
    _crypto.endSession(endpointId);

    if (_connectedEndpoints.isEmpty) {
      _state = NearbyState.idle;
    }

    notifyListeners();
  }

  // ── Payload Handling ─────────────────────────────────
  void _onPayloadReceived(String endpointId, Payload payload) {
    // An actual file (image / voice / document) is arriving. Remember it and
    // finalize when the transfer completes (see _onPayloadTransferUpdate).
    if (payload.type == PayloadType.FILE) {
      _incomingFiles[payload.id] = payload;
      return;
    }

    if (payload.type != PayloadType.BYTES || payload.bytes == null) return;
    final data = payload.bytes!;

    Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
    } catch (_) {
      // Not JSON — treat as a raw file chunk.
      _fileReceivedController.add((endpointId: endpointId, data: data));
      return;
    }

    final type = json['type'] as String?;
    switch (type) {
      case 'key_exchange':
        _handleKeyExchange(endpointId, json);
        return;
      case 'ack':
        _handleAck(json);
        return;
      case 'message':
        _handleIncomingMessage(endpointId, json);
        return;
      case 'typing':
        _typingController.add((
          endpointId: endpointId,
          isTyping: json['isTyping'] == true,
        ));
        return;
      case 'file_meta':
        // Queue the metadata; it's paired with the FILE payload on completion.
        if (_db.isBlocked(endpointId)) return;
        _pendingFileMeta.putIfAbsent(endpointId, () => []).add(json);
        return;
      case 'post':
        _handleIncomingFeed(endpointId, json, isStory: false);
        return;
      case 'story':
        _handleIncomingFeed(endpointId, json, isStory: true);
        return;
      case 'call_signal':
      case 'webrtc':
        // Real-time signaling is decrypted if needed, then passed up verbatim.
        _emitControl(endpointId, json, data);
        return;
      default:
        _emitControl(endpointId, json, data);
        return;
    }
  }

  /// Decrypt an encrypted control payload if needed, then hand it up as JSON text.
  void _emitControl(String endpointId, Map<String, dynamic> json, Uint8List raw) {
    if (json['enc'] == true) {
      final body = json['content'] as String?;
      if (body == null || !_crypto.hasSession(endpointId)) return;
      _crypto.decryptSession(endpointId, body).then((clear) {
        if (clear != null) {
          _messageReceivedController.add((endpointId: endpointId, message: clear));
        }
      });
      return;
    }
    _messageReceivedController.add((endpointId: endpointId, message: utf8.decode(raw)));
  }

  Future<void> _handleKeyExchange(String endpointId, Map<String, dynamic> json) async {
    final pub = json['pubKey'] as String?;
    final ephKey = json['ephKey'] as String?;
    final name = json['name'] as String? ?? _connectedEndpoints[endpointId] ?? 'Unknown';
    if (pub == null || pub.isEmpty) return;

    // Trust-on-first-use with pinning: remember the first key we see for a
    // peer. If a later session presents a *different* key, refuse to silently
    // trust it and warn the user — this is what a MITM/impersonation looks like.
    final pinned = _db.pinnedKeyFor(endpointId);
    if (pinned == null) {
      _db.pinKeyFor(endpointId, pub);
    } else if (pinned != pub) {
      debugPrint('[Nearby] ⚠️ KEY MISMATCH for $endpointId — refusing to trust new key');
      _keyMismatchController.add((endpointId: endpointId, name: name));
      return; // do not complete the session or flush the queue
    }

    _peerKeys[endpointId] = pub;

    // Complete the forward-secret handshake now that we have the peer's static
    // (pinned) and ephemeral keys. The authentication is bound to the pinned
    // static key; the ephemeral keys give forward secrecy.
    if (ephKey != null && ephKey.isNotEmpty) {
      final ok = await _crypto.completeSession(endpointId, pub, ephKey);
      debugPrint('[Nearby] FS session ${ok ? 'established' : 'FAILED'} with $endpointId');
    }

    // A peer is now reachable and we can encrypt to them — drain any backlog.
    _flushQueueFor(endpointId);
  }

  /// Returns true if [endpointId] is within its message rate budget.
  bool _withinRate(String endpointId) {
    final now = DateTime.now();
    final list = _msgTimestamps.putIfAbsent(endpointId, () => []);
    list.removeWhere((t) => now.difference(t) > _rateWindow);
    if (list.length >= _rateMaxInWindow) {
      debugPrint('[Nearby] Rate limit hit for $endpointId — dropping message');
      return false;
    }
    list.add(now);
    return true;
  }

  void _handleAck(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null) return;
    _queue.remove(id);
    final msg = _db.getMessage(id);
    if (msg != null && msg.status != MessageStatus.read) {
      msg.status = MessageStatus.delivered;
      msg.save();
      notifyListeners();
    }
  }

  void _handleIncomingMessage(String endpointId, Map<String, dynamic> json) {
    // Drop anything from a blocked peer, silently.
    if (_db.isBlocked(endpointId)) return;

    // Spam control: ignore peers exceeding the rate budget.
    if (!_withinRate(endpointId)) return;

    final id = json['id'] as String? ?? _uuid.v4();

    // Idempotent delivery: a re-sent (queued/retried) message is ignored.
    if (_db.getMessage(id) != null) {
      _sendAck(endpointId, id); // re-ack in case our previous ack was lost
      return;
    }

    final senderId = json['senderId'] as String? ?? endpointId;
    final senderName =
        json['senderName'] as String? ?? _connectedEndpoints[endpointId] ?? 'Unknown';
    final isEncrypted = json['enc'] == true;
    final rawContent = json['content'] as String? ?? '';

    String? content = rawContent;
    if (isEncrypted) {
      // Decrypt only with the forward-secret session key established via the
      // pinned-identity handshake. No fallback to an inline per-message key —
      // that would let an attacker assert a fresh identity and defeat pinning.
      if (!_crypto.hasSession(endpointId)) {
        debugPrint('[Nearby] Encrypted message but no secure session — dropping');
        return;
      }
      // Decryption is async; finish handling there.
      _crypto.decryptSession(endpointId, rawContent).then((clear) {
        if (clear == null) {
          debugPrint('[Nearby] Failed to decrypt message $id — dropping');
          return;
        }
        _persistIncoming(endpointId, id, senderId, senderName, clear);
      });
      return;
    }

    if (content.isEmpty) return;
    _persistIncoming(endpointId, id, senderId, senderName, content);
  }

  void _persistIncoming(String endpointId, String id, String senderId,
      String senderName, String content) {
    final convId = 'conv_$endpointId';
    final msg = Message(
      id: id,
      conversationId: convId,
      senderId: senderId,
      receiverId: _myId,
      content: content,
      messageTypeIndex: MessageType.text.index,
      statusIndex: MessageStatus.delivered.index,
      transportTypeIndex: TransportType.ble.index,
    );
    _db.saveMessage(msg);

    var conv = _db.getConversation(convId);
    conv ??= Conversation(
      id: convId,
      peerId: endpointId,
      peerName: senderName,
      peerAvatarColorIndex: senderName.hashCode.abs() % AvatarColors.palette.length,
    );
    conv.lastMessage = content;
    conv.lastMessageTime = DateTime.now();
    conv.unreadCount += 1;
    _db.saveConversation(conv);

    // Do NOT log message content — it would leak plaintext into logcat.
    debugPrint('[Nearby] Message received from $endpointId');
    StreakService().recordPeer(convId);
    _messageReceivedController.add((endpointId: endpointId, message: content));
    NotificationService().showMessage(
      conversationId: convId, title: senderName, body: content);
    _sendAck(endpointId, id);
    notifyListeners();
  }

  // ── Key exchange + acks ──────────────────────────────
  Future<void> _sendKeyExchange(String endpointId) async {
    try {
      // Fresh ephemeral key for this connection → forward secrecy.
      final ephKey = await _crypto.startSession(endpointId);
      final payload = jsonEncode({
        'type': 'key_exchange',
        'userId': _myId,
        'name': _myName,
        'pubKey': _crypto.myPublicKeyBase64, // long-lived, pinned (auth)
        'ephKey': ephKey, // ephemeral, per-session (forward secrecy)
      });
      await _nearby.sendBytesPayload(
          endpointId, Uint8List.fromList(utf8.encode(payload)));
    } catch (e) {
      debugPrint('[Nearby] Key exchange send failed: $e');
    }
  }

  Future<void> _sendAck(String endpointId, String messageId) async {
    try {
      final payload = jsonEncode({'type': 'ack', 'id': messageId});
      await _nearby.sendBytesPayload(
          endpointId, Uint8List.fromList(utf8.encode(payload)));
    } catch (_) {/* best effort */}
  }

  /// Try to deliver any queued messages addressed to [endpointId].
  Future<void> _flushQueueFor(String endpointId) async {
    final pending = _queue.pendingFor(endpointId);
    for (final q in pending) {
      final ok = await _sendMessageInternal(
        endpointId,
        messageId: q.messageId,
        content: q.content,
      );
      if (ok) {
        _queue.markAttempt(q.messageId);
      }
    }
  }

  /// Progress callbacks for in-flight file payloads, keyed by Nearby payload id.
  final Map<int, void Function(double)> _fileProgress = {};

  void _onPayloadTransferUpdate(String endpointId, PayloadTransferUpdate update) {
    // Outgoing transfer: report progress to the sender's UI.
    if (_fileProgress.containsKey(update.id)) {
      if (update.totalBytes > 0) {
        final progress = update.bytesTransferred / update.totalBytes;
        _fileProgress[update.id]?.call(progress.clamp(0.0, 1.0));
      }
      if (update.status == PayloadStatus.SUCCESS ||
          update.status == PayloadStatus.FAILURE) {
        _fileProgress.remove(update.id);
      }
      return;
    }

    // Incoming file finished transferring: save it and persist a Message.
    if (_incomingFiles.containsKey(update.id) &&
        update.status == PayloadStatus.SUCCESS) {
      final payload = _incomingFiles.remove(update.id)!;
      _finalizeIncomingFile(endpointId, payload);
    } else if (update.status == PayloadStatus.FAILURE) {
      _incomingFiles.remove(update.id);
    }
  }

  /// Copy a received file into app storage and persist it as a chat message,
  /// pairing it with the file_meta the sender sent just before it.
  Future<void> _finalizeIncomingFile(String endpointId, Payload payload) async {
    if (_db.isBlocked(endpointId)) return;
    final meta = (_pendingFileMeta[endpointId]?.isNotEmpty ?? false)
        ? _pendingFileMeta[endpointId]!.removeAt(0)
        : <String, dynamic>{};

    final dir = await getApplicationDocumentsDirectory();
    final fileName = (meta['fileName'] as String?) ??
        'recv_${DateTime.now().millisecondsSinceEpoch}';
    final destPath = '${dir.path}/$fileName';

    try {
      // On modern Android the plugin delivers received files as a content URI
      // (content://…), which is NOT a filesystem path — File().copy() on it
      // fails and the image never renders. Use the plugin's native copy helper
      // for the URI case, and a plain file copy on older builds.
      final uri = payload.uri;
      // ignore: deprecated_member_use
      final legacyPath = payload.filePath;
      if (uri != null && uri.isNotEmpty) {
        final ok = await _nearby.copyFileAndDeleteOriginal(uri, destPath);
        if (!ok) {
          debugPrint('[Nearby] copyFileAndDeleteOriginal failed — dropping');
          return;
        }
      } else if (legacyPath != null) {
        final src = File(legacyPath);
        if (!await src.exists()) return;
        await src.copy(destPath);
      } else {
        debugPrint('[Nearby] Received file but no path/uri — dropping');
        return;
      }

      // The peer controls msgType — validate it so a bogus index can't crash
      // rendering (MessageType.values[index] would throw a RangeError).
      final rawType = (meta['msgType'] as int?) ?? MessageType.image.index;
      final typeIdx = (rawType >= 0 && rawType < MessageType.values.length)
          ? rawType
          : MessageType.file.index;
      final convId = 'conv_$endpointId';
      final id = (meta['id'] as String?) ?? _uuid.v4();
      if (_db.getMessage(id) != null) return; // idempotent

      final senderName = _connectedEndpoints[endpointId] ?? 'Unknown';
      final msg = Message(
        id: id,
        conversationId: convId,
        senderId: endpointId,
        receiverId: _myId,
        content: (meta['caption'] as String?) ?? _mediaLabel(typeIdx),
        messageTypeIndex: typeIdx,
        statusIndex: MessageStatus.delivered.index,
        transportTypeIndex: TransportType.ble.index,
        mediaPath: destPath,
        durationMs: meta['durationMs'] as int?,
        mediaSizeBytes: await File(destPath).length(),
      );
      _db.saveMessage(msg);

      var conv = _db.getConversation(convId);
      conv ??= Conversation(
        id: convId,
        peerId: endpointId,
        peerName: senderName,
        peerAvatarColorIndex: senderName.hashCode.abs() % AvatarColors.palette.length,
      );
      conv.lastMessage = msg.content;
      conv.lastMessageTime = DateTime.now();
      conv.unreadCount += 1;
      _db.saveConversation(conv);

      StreakService().recordPeer(convId);
      _mediaReceivedController.add((endpointId: endpointId, conversationId: convId));
      NotificationService().showMessage(
        conversationId: convId, title: senderName, body: msg.content);
      notifyListeners();
      debugPrint('[Nearby] Saved received media → $destPath');
    } catch (e) {
      debugPrint('[Nearby] Failed to save received file: $e');
    }
  }

  String _mediaLabel(int typeIdx) {
    if (typeIdx == MessageType.voice.index) return '🎤 Voice message';
    if (typeIdx == MessageType.video.index) return '🎬 Video';
    if (typeIdx == MessageType.image.index) return '📷 Photo';
    return '📎 File';
  }

  // ── Incoming feed (posts / stories) ──────────────────
  Future<void> _handleIncomingFeed(String endpointId, Map<String, dynamic> json,
      {required bool isStory}) async {
    if (_db.isBlocked(endpointId)) return;
    if (!_withinRate(endpointId)) return;

    // Feed items are encrypted with the session key; unseal before ingesting.
    if (json['enc'] == true) {
      final body = json['content'] as String?;
      if (body == null || !_crypto.hasSession(endpointId)) return;
      final clear = await _crypto.decryptSession(endpointId, body);
      if (clear == null) return;
      try {
        json = jsonDecode(clear) as Map<String, dynamic>;
      } catch (_) {
        return;
      }
    }

    final id = json['id'] as String?;
    if (id == null) return;

    try {
      if (isStory) {
        if (_db.getStory(id) != null) return;
        final created = DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now();
        _db.saveStory(Story(
          id: id,
          authorId: json['authorId'] as String? ?? endpointId,
          authorName: json['authorName'] as String? ?? 'Nearby',
          authorAvatarColorIndex: json['color'] as int? ?? 0,
          textOverlay: json['text'] as String?,
          createdAt: created,
          expiresAt: created.add(const Duration(hours: 24)),
        ));
      } else {
        if (_db.getPost(id) != null) return;
        _db.savePost(Post(
          id: id,
          authorId: json['authorId'] as String? ?? endpointId,
          authorName: json['authorName'] as String? ?? 'Nearby',
          authorAvatarColorIndex: json['color'] as int? ?? 0,
          textContent: json['text'] as String?,
          createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
              DateTime.now(),
          distanceMeters: 0,
        ));
      }
      _feedController.add(id);
      notifyListeners();
    } catch (e) {
      debugPrint('[Nearby] Failed to ingest feed item: $e');
    }
  }

  // ── Connect to a discovered endpoint ─────────────────
  Future<bool> connectToEndpoint(String endpointId) async {
    try {
      // Outgoing connection = the user chose this peer, so it's pre-approved
      // (no incoming-request dialog needed on our side).
      _approvedEndpoints.add(endpointId);
      final device = _discoveredEndpoints[endpointId];
      if (device != null) {
        device.connectionStateIndex = ConnectionState.connecting.index;
        notifyListeners();
      }

      await _nearby.requestConnection(
        _myName,
        endpointId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );

      return true;
    } catch (e) {
      debugPrint('[Nearby] Connect request failed: $e');
      return false;
    }
  }

  // ── Send Text Message ────────────────────────────────
  /// Send a chat message. If the peer is unreachable, the message is queued
  /// (store-and-forward) and retried automatically when they reconnect.
  /// Returns true if it left this device now, false if it was queued.
  Future<bool> sendMessage(String endpointId, String content,
      {String? messageId}) async {
    final id = messageId ?? _uuid.v4();

    if (!_connectedEndpoints.containsKey(endpointId)) {
      debugPrint('[Nearby] Not connected to $endpointId — queuing $id');
      await _queue.enqueue(messageId: id, recipientId: endpointId, content: content);
      return false;
    }

    final ok = await _sendMessageInternal(endpointId, messageId: id, content: content);
    if (!ok) {
      await _queue.enqueue(messageId: id, recipientId: endpointId, content: content);
    }
    return ok;
  }

  /// Actually serialize + (optionally encrypt) + transmit a chat message.
  Future<bool> _sendMessageInternal(String endpointId,
      {required String messageId, required String content}) async {
    try {
      String wireContent = content;
      bool encrypted = false;

      // Encrypt with the forward-secret session key for this connection.
      if (_crypto.hasSession(endpointId)) {
        final sealed = await _crypto.encryptSession(endpointId, content);
        if (sealed != null) {
          wireContent = sealed;
          encrypted = true;
        }
      }

      // Note: we intentionally do NOT include our public key inline. The peer
      // trusts only the key it pinned during key-exchange, so an inline key
      // would be ignored anyway — and omitting it removes a spoofing vector.
      final json = jsonEncode({
        'type': 'message',
        'id': messageId,
        'enc': encrypted,
        'content': wireContent,
        'senderId': _myId,
        'senderName': _myName,
        'timestamp': DateTime.now().toIso8601String(),
      });

      await _nearby.sendBytesPayload(
          endpointId, Uint8List.fromList(utf8.encode(json)));
      debugPrint('[Nearby] Sent $messageId to $endpointId (enc=$encrypted)');
      return true;
    } catch (e) {
      debugPrint('[Nearby] Send failed: $e');
      return false;
    }
  }

  /// Send a control payload (call/WebRTC signaling). When [encrypt] is set and
  /// a session key exists, the payload body is sealed so signaling isn't sent
  /// in the clear; the envelope keeps its `type` so the peer can still route it.
  Future<bool> sendJson(String endpointId, Map<String, dynamic> payload,
      {bool encrypt = true}) async {
    if (!_connectedEndpoints.containsKey(endpointId)) return false;
    try {
      Map<String, dynamic> wire = payload;
      if (encrypt && _crypto.hasSession(endpointId)) {
        final sealed = await _crypto.encryptSession(endpointId, jsonEncode(payload));
        if (sealed != null) {
          wire = {'type': payload['type'], 'enc': true, 'content': sealed};
        }
      }
      await _nearby.sendBytesPayload(
          endpointId, Uint8List.fromList(utf8.encode(jsonEncode(wire))));
      return true;
    } catch (e) {
      debugPrint('[Nearby] sendJson failed: $e');
      return false;
    }
  }

  /// Broadcast a feed post (or story) to every connected peer so it propagates
  /// device-to-device. Encrypted per-peer with the forward-secret session key;
  /// falls back to plaintext only if a peer somehow has no session yet.
  Future<void> broadcastFeed(Map<String, dynamic> item) async {
    final type = item['type'];
    for (final endpointId in _connectedEndpoints.keys) {
      try {
        Map<String, dynamic> wire = item;
        if (_crypto.hasSession(endpointId)) {
          final sealed = await _crypto.encryptSession(endpointId, jsonEncode(item));
          if (sealed != null) {
            wire = {'type': type, 'enc': true, 'content': sealed};
          }
        }
        await _nearby.sendBytesPayload(
            endpointId, Uint8List.fromList(utf8.encode(jsonEncode(wire))));
      } catch (_) {/* best effort */}
    }
  }

  // ── Send File ────────────────────────────────────────
  Future<bool> sendFile(String endpointId, String filePath,
      {void Function(double)? onProgress, Map<String, dynamic>? meta}) async {
    if (!_connectedEndpoints.containsKey(endpointId)) return false;

    try {
      // Send file metadata first so the receiver can rebuild the message.
      final metaJson = jsonEncode({
        'type': 'file_meta',
        'fileName': filePath.split('/').last,
        'senderId': _myId,
        ...?meta,
      });
      await _nearby.sendBytesPayload(
        endpointId,
        Uint8List.fromList(utf8.encode(metaJson)),
      );

      // Then send the file, tracking real transfer progress.
      final payloadId = await _nearby.sendFilePayload(endpointId, filePath);
      if (onProgress != null) _fileProgress[payloadId] = onProgress;
      debugPrint('[Nearby] File sending, payload ID: $payloadId');
      return true;
    } catch (e) {
      debugPrint('[Nearby] File send failed: $e');
      return false;
    }
  }

  // ── Disconnect ───────────────────────────────────────
  Future<void> disconnectFrom(String endpointId) async {
    await _nearby.disconnectFromEndpoint(endpointId);
    _connectedEndpoints.remove(endpointId);
    notifyListeners();
  }

  Future<void> disconnectAll() async {
    await _nearby.stopAllEndpoints();
    _connectedEndpoints.clear();
    _state = NearbyState.idle;
    notifyListeners();
  }

  // ── Cleanup ──────────────────────────────────────────
  // ChangeNotifier.dispose() is synchronous, so we must NOT make this async
  // (the caller can't await it through the ChangeNotifier contract). Kick off
  // the radio teardown as fire-and-forget, then close controllers + super.
  @override
  void dispose() {
    unawaited(stopAll());
    unawaited(disconnectAll());
    _deviceDiscoveredController.close();
    _deviceLostController.close();
    _messageReceivedController.close();
    _connectionController.close();
    _fileReceivedController.close();
    _mediaReceivedController.close();
    _feedController.close();
    _typingController.close();
    _pendingConnectionController.close();
    _keyMismatchController.close();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────
  bool isConnectedTo(String endpointId) => _connectedEndpoints.containsKey(endpointId);
  int get connectedCount => _connectedEndpoints.length;
  int get discoveredCount => _discoveredEndpoints.length;

  void clearDiscovered() {
    _discoveredEndpoints.clear();
    notifyListeners();
  }
}
