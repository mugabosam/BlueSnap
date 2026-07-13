/// BlueSnap Bluetooth Service — single transport facade.
///
/// Real phone-to-phone communication via Google Nearby Connections. There is
/// no simulation path: what the UI shows is what actually happened on the
/// radio. Presence, delivery state, and discovery all reflect real events.
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../data/models/models.dart';
import '../data/database/database_service.dart';
import 'nearby_service.dart';

enum BluetoothServiceState { idle, scanning, advertising, connected, error }

class BluetoothService extends ChangeNotifier {
  static final BluetoothService _instance = BluetoothService._();
  factory BluetoothService() => _instance;
  BluetoothService._();

  final DatabaseService _db = DatabaseService();
  final NearbyService _nearby = NearbyService();

  BluetoothServiceState _state = BluetoothServiceState.idle;
  BluetoothServiceState get state => _state;

  final List<NearbyDevice> _discoveredDevices = [];
  List<NearbyDevice> get discoveredDevices => List.unmodifiable(_discoveredDevices);

  String? _connectedDeviceId;
  String? get connectedDeviceId => _connectedDeviceId;

  // Streams
  final _deviceDiscoveredController = StreamController<NearbyDevice>.broadcast();
  Stream<NearbyDevice> get onDeviceDiscovered => _deviceDiscoveredController.stream;
  final _deviceLostController = StreamController<String>.broadcast();
  Stream<String> get onDeviceLost => _deviceLostController.stream;
  final _messageReceivedController = StreamController<Message>.broadcast();
  Stream<Message> get onMessageReceived => _messageReceivedController.stream;
  final _stateController = StreamController<BluetoothServiceState>.broadcast();
  Stream<BluetoothServiceState> get onStateChanged => _stateController.stream;
  final _callSignalController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onCallSignalReceived => _callSignalController.stream;
  final _webrtcController = StreamController<Map<String, dynamic>>.broadcast();
  /// WebRTC signaling (offer/answer/ICE) relayed from the peer over Nearby.
  Stream<Map<String, dynamic>> get onWebrtcSignal => _webrtcController.stream;

  /// Send a WebRTC signaling payload to the peer (encrypted over Nearby).
  Future<bool> sendWebrtc(String peerId, Map<String, dynamic> data) {
    final endpointId = _connectedDeviceId ?? peerId;
    return _nearby.sendJson(endpointId, {'type': 'webrtc', ...data});
  }
  final _connectionController =
      StreamController<({String endpointId, bool connected})>.broadcast();
  Stream<({String endpointId, bool connected})> get onConnectionChanged =>
      _connectionController.stream;

  /// A media file was received, saved, and persisted as a message.
  Stream<({String endpointId, String conversationId})> get onMediaReceived =>
      _nearby.onMediaReceived;

  /// A feed post/story arrived from a peer.
  Stream<String> get onFeedUpdated => _nearby.onFeedUpdated;

  bool _listenersWired = false;

  // ── Init ─────────────────────────────────────────────
  /// Idempotent. Safe to call again after onboarding creates the profile —
  /// it (re)initializes the Nearby identity with the current user without
  /// re-wiring the stream listeners (which would double-process every event).
  Future<void> init() async {
    _state = BluetoothServiceState.idle;
    _stateController.add(_state);

    final user = _db.currentUser;
    if (user != null) {
      await _nearby.init(userName: user.displayName, userId: user.id);
    }

    if (_listenersWired) return; // identity refreshed; don't re-add listeners
    _listenersWired = true;

    if (user == null) {
      debugPrint('[BluetoothService] No current user yet — Nearby starts after onboarding.');
    }

    _nearby.onDeviceDiscovered.listen((device) {
      // Never surface a blocked peer.
      if (_db.isBlocked(device.deviceId)) return;
      final idx = _discoveredDevices.indexWhere((d) => d.deviceId == device.deviceId);
      if (idx >= 0) {
        _discoveredDevices[idx] = device;
      } else {
        _discoveredDevices.add(device);
      }
      _deviceDiscoveredController.add(device);
      notifyListeners();
    });

    _nearby.onDeviceLost.listen((id) {
      _discoveredDevices.removeWhere((d) => d.deviceId == id);
      _deviceLostController.add(id);
      notifyListeners();
    });

    _nearby.onMessageReceived.listen((event) {
      // Call + WebRTC signals arrive on this channel as JSON.
      try {
        final parsed = jsonDecode(event.message) as Map<String, dynamic>;
        if (parsed['type'] == 'call_signal') {
          if (_db.isBlocked(event.endpointId)) return;
          _callSignalController.add({
            'type': parsed['signalType'],
            'callType': parsed['callType'],
            'peerId': event.endpointId,
            'peerName': parsed['senderName'] ?? 'Unknown',
          });
          notifyListeners();
          return;
        }
        if (parsed['type'] == 'webrtc') {
          if (_db.isBlocked(event.endpointId)) return;
          _webrtcController.add({...parsed, 'peerId': event.endpointId});
          return;
        }
      } catch (_) {
        // Plain text — NearbyService already persisted it; just notify listeners.
      }
      // Text messages are persisted inside NearbyService; forward for UI refresh.
      final convId = 'conv_${event.endpointId}';
      final msg = _db.getMessages(convId).isNotEmpty
          ? _db.getMessages(convId).last
          : null;
      if (msg != null) _messageReceivedController.add(msg);
      notifyListeners();
    });

    _nearby.onConnectionChanged.listen((event) {
      if (event.connected) {
        _connectedDeviceId = event.endpointId;
        _state = BluetoothServiceState.connected;
      } else if (_connectedDeviceId == event.endpointId) {
        _connectedDeviceId = null;
        _state = BluetoothServiceState.idle;
      }
      _connectionController.add((endpointId: event.endpointId, connected: event.connected));
      _stateController.add(_state);
      notifyListeners();
    });
  }

  // ── Presence (real) ──────────────────────────────────
  /// True only when there is a live Nearby connection to this peer.
  bool isPeerOnline(String endpointId) => _nearby.isConnectedTo(endpointId);

  // ── Scanning ─────────────────────────────────────────
  Future<void> startScan() async {
    if (_state == BluetoothServiceState.scanning) return;
    _state = BluetoothServiceState.scanning;
    _stateController.add(_state);
    notifyListeners();
    // Advertise + discover so this phone is visible AND scanning.
    await _nearby.startBoth();
  }

  Future<void> stopScan() async {
    await _nearby.stopAll();
    _state = BluetoothServiceState.idle;
    _stateController.add(_state);
    notifyListeners();
  }

  // ── Connection ───────────────────────────────────────
  Future<bool> connectToDevice(String deviceId) async {
    if (_db.isBlocked(deviceId)) return false;
    final dIdx = _discoveredDevices.indexWhere((d) => d.deviceId == deviceId);
    if (dIdx == -1) return false;

    _discoveredDevices[dIdx].connectionStateIndex = ConnectionState.connecting.index;
    notifyListeners();

    final ok = await _nearby.connectToEndpoint(deviceId);

    _discoveredDevices[dIdx].connectionStateIndex =
        ok ? ConnectionState.connected.index : ConnectionState.disconnected.index;
    if (ok) {
      _connectedDeviceId = deviceId;
      _state = BluetoothServiceState.connected;
    }
    _stateController.add(_state);
    notifyListeners();
    return ok;
  }

  Future<void> disconnect() async {
    if (_connectedDeviceId != null) {
      await _nearby.disconnectFrom(_connectedDeviceId!);
      final idx = _discoveredDevices.indexWhere((d) => d.deviceId == _connectedDeviceId);
      if (idx != -1) {
        _discoveredDevices[idx].connectionStateIndex = ConnectionState.disconnected.index;
      }
    }
    _connectedDeviceId = null;
    _state = BluetoothServiceState.idle;
    _stateController.add(_state);
    notifyListeners();
  }

  // ── Send Message ─────────────────────────────────────
  /// Returns true if the message left the device now, false if it was queued
  /// for store-and-forward (peer unreachable) or refused (blocked).
  Future<bool> sendMessage(Message message) async {
    if (_db.isBlocked(message.receiverId)) {
      message.status = MessageStatus.failed;
      await _db.saveMessage(message);
      notifyListeners();
      return false;
    }
    final endpointId = _connectedDeviceId ?? message.receiverId;
    final sent = await _nearby.sendMessage(
      endpointId,
      message.content,
      messageId: message.id,
    );
    message.status = sent ? MessageStatus.sent : MessageStatus.sending;
    await _db.saveMessage(message);
    notifyListeners();
    return sent;
  }

  // ── Typing signal (real) ─────────────────────────────
  Future<void> sendTyping(String peerId, bool isTyping) async {
    final endpointId = _connectedDeviceId ?? peerId;
    await _nearby.sendJson(endpointId, {
      'type': 'typing',
      'isTyping': isTyping,
    });
  }

  Stream<({String endpointId, bool isTyping})> get onTypingChanged =>
      _nearby.onTypingChanged;

  // ── Call Signaling ───────────────────────────────────
  Future<bool> sendCallSignal({
    required String peerId,
    required String signalType,
    required String callType,
  }) async {
    if (_db.isBlocked(peerId)) return false;
    final endpointId = _connectedDeviceId ?? peerId;
    return await _nearby.sendJson(endpointId, {
      'type': 'call_signal',
      'signalType': signalType,
      'callType': callType,
      'senderId': _db.currentUser?.id ?? '',
      'senderName': _db.currentUser?.displayName ?? '',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // ── Send File (real) ─────────────────────────────────
  Future<bool> sendFile({
    required String filePath,
    required String receiverId,
    required String conversationId,
    required int fileSizeBytes,
    void Function(double)? onProgress,
    Map<String, dynamic>? meta,
  }) async {
    if (_db.isBlocked(receiverId)) return false;
    final endpointId = _connectedDeviceId ?? receiverId;
    return await _nearby.sendFile(endpointId, filePath,
        onProgress: onProgress, meta: meta);
  }

  /// Broadcast a text feed post/story to all connected peers.
  Future<void> broadcastFeed(Map<String, dynamic> item) =>
      _nearby.broadcastFeed(item);

  Future<void> startAdvertising(User currentUser) async {
    await _nearby.init(userName: currentUser.displayName, userId: currentUser.id);
    await _nearby.startAdvertising();
  }

  @override
  void dispose() {
    _deviceDiscoveredController.close();
    _deviceLostController.close();
    _messageReceivedController.close();
    _stateController.close();
    _callSignalController.close();
    _webrtcController.close();
    _connectionController.close();
    _nearby.dispose();
    super.dispose();
  }

  NearbyDevice? getDevice(String deviceId) {
    try {
      return _discoveredDevices.firstWhere((d) => d.deviceId == deviceId);
    } catch (_) {
      return null;
    }
  }

  void clearDiscovered() {
    _discoveredDevices.clear();
    _db.clearNearbyDevices();
    notifyListeners();
  }

  int get deviceCount => _discoveredDevices.length;
  bool get isScanning => _state == BluetoothServiceState.scanning;
}
