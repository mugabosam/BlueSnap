/// BlueSnap end-to-end encryption.
///
/// v1 scheme (intentionally simple, upgradeable later):
///   - Each device has a long-lived X25519 identity key pair.
///   - Public keys are exchanged over the wire on connect (see NearbyService).
///   - A per-peer session key is derived with X25519 ECDH + HKDF-SHA256.
///   - Message payloads are sealed with AES-256-GCM (authenticated encryption).
///
/// This gives confidentiality + integrity for direct chats without any server.
/// Forward secrecy (Double Ratchet) is deliberately out of scope for v1.
library;

import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/database/database_service.dart';

class CryptoService {
  static final CryptoService _instance = CryptoService._();
  factory CryptoService() => _instance;
  CryptoService._();

  static const _privKeySettingKey = 'crypto_identity_seed_v1';
  static const _pubKeySettingKey = 'crypto_identity_pub_v1';
  static const _hkdfInfo = 'bluesnap-session-v1';
  static const _nonceLength = 12; // AES-GCM standard nonce
  static const _macLength = 16; // GCM tag

  final _x25519 = X25519();
  final _aes = AesGcm.with256bits();
  final DatabaseService _db = DatabaseService();

  /// Hardware-backed key storage (Android Keystore / iOS Keychain). The private
  /// identity seed never touches the plaintext Hive database.
  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  SimpleKeyPair? _identityKeyPair;
  String _myPublicKeyB64 = '';

  /// Derived session keys cached per peer public key (base64).
  final Map<String, SecretKey> _sessionCache = {};

  bool get isReady => _identityKeyPair != null;

  /// Our identity public key, base64-encoded. Empty until [init] completes.
  String get myPublicKeyBase64 => _myPublicKeyB64;

  /// Load the persisted identity key pair, or generate one on first launch.
  Future<void> init() async {
    if (_identityKeyPair != null) return;

    // 1. Preferred: seed from hardware-backed secure storage.
    var storedSeed = await _secure.read(key: _privKeySettingKey);

    // 2. One-time migration: older builds kept the seed in plaintext Hive.
    //    Move it into secure storage and scrub the old copy.
    if (storedSeed == null || storedSeed.isEmpty) {
      final legacy = _db.getSetting(_privKeySettingKey);
      if (legacy is String && legacy.isNotEmpty) {
        storedSeed = legacy;
        await _secure.write(key: _privKeySettingKey, value: legacy);
        await _db.setSetting(_privKeySettingKey, '');
        debugPrint('[Crypto] Migrated identity seed to secure storage');
      }
    }

    if (storedSeed != null && storedSeed.isNotEmpty) {
      try {
        final seed = base64.decode(storedSeed);
        _identityKeyPair = await _x25519.newKeyPairFromSeed(seed);
        _myPublicKeyB64 = _db.getSetting(_pubKeySettingKey) as String? ?? '';
        if (_myPublicKeyB64.isEmpty) {
          await _cachePublicKey();
        }
        return;
      } catch (e) {
        debugPrint('[Crypto] Failed to restore identity, regenerating: $e');
      }
    }

    _identityKeyPair = await _x25519.newKeyPair();
    final priv = await _identityKeyPair!.extractPrivateKeyBytes();
    await _secure.write(key: _privKeySettingKey, value: base64.encode(priv));
    await _cachePublicKey();
    debugPrint('[Crypto] Generated new identity key (secure storage)');
  }

  Future<void> _cachePublicKey() async {
    final pub = await _identityKeyPair!.extractPublicKey();
    _myPublicKeyB64 = base64.encode(pub.bytes);
    // The public key is not secret; keep it in Hive for cheap synchronous reads.
    await _db.setSetting(_pubKeySettingKey, _myPublicKeyB64);
  }

  /// Derive (and cache) the AES session key shared with [peerPublicKeyB64].
  Future<SecretKey?> _sessionKey(String peerPublicKeyB64) async {
    if (_identityKeyPair == null) return null;
    final cached = _sessionCache[peerPublicKeyB64];
    if (cached != null) return cached;

    try {
      final peerPub = SimplePublicKey(
        base64.decode(peerPublicKeyB64),
        type: KeyPairType.x25519,
      );
      final shared = await _x25519.sharedSecretKey(
        keyPair: _identityKeyPair!,
        remotePublicKey: peerPub,
      );
      final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
      final sessionKey = await hkdf.deriveKey(
        secretKey: shared,
        info: utf8.encode(_hkdfInfo),
      );
      _sessionCache[peerPublicKeyB64] = sessionKey;
      return sessionKey;
    } catch (e) {
      debugPrint('[Crypto] Session derivation failed: $e');
      return null;
    }
  }

  /// Encrypt [plaintext] for [peerPublicKeyB64].
  /// Returns base64(nonce ++ ciphertext ++ mac), or null if no session.
  Future<String?> encryptFor(String peerPublicKeyB64, String plaintext) async {
    final key = await _sessionKey(peerPublicKeyB64);
    if (key == null) return null;
    final box = await _aes.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
    );
    return base64.encode(box.concatenation());
  }

  /// Decrypt a payload produced by [encryptFor]. Returns null on auth failure.
  Future<String?> decryptFrom(String peerPublicKeyB64, String payloadB64) async {
    final key = await _sessionKey(peerPublicKeyB64);
    if (key == null) return null;
    try {
      final bytes = base64.decode(payloadB64);
      final box = SecretBox.fromConcatenation(
        bytes,
        nonceLength: _nonceLength,
        macLength: _macLength,
      );
      final clear = await _aes.decrypt(box, secretKey: key);
      return utf8.decode(clear);
    } catch (e) {
      debugPrint('[Crypto] Decrypt/verify failed: $e');
      return null;
    }
  }

  /// Short human-comparable fingerprint of a public key, for verification UI.
  /// (Render this on both phones; matching digits => no man-in-the-middle.)
  static String fingerprint(String publicKeyB64) {
    if (publicKeyB64.isEmpty) return '----';
    final bytes = base64.decode(publicKeyB64);
    final h = _fnv1a(bytes);
    final digits = (h % 1000000000000).toString().padLeft(12, '0');
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i += 4) {
      if (i > 0) out.write(' ');
      out.write(digits.substring(i, i + 4));
    }
    return out.toString();
  }

  // 32-bit FNV-1a. The 64-bit variant's constants exceed JS's safe integer
  // range, so they can't compile for web; 32-bit fits and is stable across
  // web and native targets.
  static int _fnv1a(Uint8List data) {
    var hash = 0x811c9dc5;
    const prime = 0x01000193;
    for (final b in data) {
      hash ^= b;
      hash = (hash * prime) & 0xFFFFFFFF;
    }
    return hash;
  }

  void clearSessions() => _sessionCache.clear();
}
