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

  // ══════════════════════════════════════════════════════════
  // Forward-secret sessions (per connection)
  //
  // Each connection runs an authenticated ephemeral handshake — a triple
  // Diffie–Hellman that mixes both sides' long-lived identity keys (for
  // authentication, so it's still bound to the pinned key) AND fresh ephemeral
  // keys (for forward secrecy). The ephemeral private keys live only in memory
  // and are wiped when the session ends, so a later compromise of the identity
  // keys can't decrypt past sessions. This is the Noise-IK / X3DH shape.
  // ══════════════════════════════════════════════════════════

  final Map<String, SimpleKeyPair> _ephemeral = {}; // sessionId -> my ephemeral
  final Map<String, SecretKey> _fsSessions = {}; // sessionId -> derived AES key

  /// Begin a forward-secret session; returns our ephemeral public key (base64)
  /// to send to the peer in the handshake.
  Future<String> startSession(String sessionId) async {
    final kp = await _x25519.newKeyPair();
    _ephemeral[sessionId] = kp;
    final pub = await kp.extractPublicKey();
    return base64.encode(pub.bytes);
  }

  /// Complete the handshake once the peer's static + ephemeral keys are known.
  /// Both sides derive the identical session key regardless of who connected.
  Future<bool> completeSession(
      String sessionId, String peerStaticB64, String peerEphemeralB64) async {
    final myEph = _ephemeral[sessionId];
    if (myEph == null || _identityKeyPair == null) return false;
    try {
      final myStaticPub = await _identityKeyPair!.extractPublicKey();
      final peerStatic = SimplePublicKey(base64.decode(peerStaticB64),
          type: KeyPairType.x25519);
      final peerEph = SimplePublicKey(base64.decode(peerEphemeralB64),
          type: KeyPairType.x25519);

      // Canonical roles so both sides concatenate the DH results in one order.
      // "A" is the party with the lexicographically-smaller static public key.
      final amA = _compareBytes(myStaticPub.bytes, peerStatic.bytes) < 0;

      // The three shared secrets, always in A-order: (eph_A·stat_B),
      // (stat_A·eph_B), (eph_A·eph_B). Each party can compute all three.
      final List<int> dhES, dhSE, dhEE;
      if (amA) {
        dhES = await _dh(myEph, peerStatic); // eph_A · stat_B
        dhSE = await _dh(_identityKeyPair!, peerEph); // stat_A · eph_B
      } else {
        dhES = await _dh(_identityKeyPair!, peerEph); // eph_A · stat_B (I'm B)
        dhSE = await _dh(myEph, peerStatic); // stat_A · eph_B (I'm B)
      }
      dhEE = await _dh(myEph, peerEph); // eph_A · eph_B

      final ikm = <int>[...dhES, ...dhSE, ...dhEE];
      final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
      final key = await hkdf.deriveKey(
        secretKey: SecretKey(ikm),
        info: utf8.encode('$_hkdfInfo-fs'),
      );
      _fsSessions[sessionId] = key;
      return true;
    } catch (e) {
      debugPrint('[Crypto] FS session derivation failed: $e');
      return false;
    }
  }

  bool hasSession(String sessionId) => _fsSessions.containsKey(sessionId);

  /// Encrypt with the forward-secret session key. Null if no session yet.
  Future<String?> encryptSession(String sessionId, String plaintext) async {
    final key = _fsSessions[sessionId];
    if (key == null) return null;
    final box = await _aes.encrypt(utf8.encode(plaintext), secretKey: key);
    return base64.encode(box.concatenation());
  }

  /// Decrypt with the forward-secret session key. Null on auth failure / no session.
  Future<String?> decryptSession(String sessionId, String payloadB64) async {
    final key = _fsSessions[sessionId];
    if (key == null) return null;
    try {
      final bytes = base64.decode(payloadB64);
      final box = SecretBox.fromConcatenation(bytes,
          nonceLength: _nonceLength, macLength: _macLength);
      return utf8.decode(await _aes.decrypt(box, secretKey: key));
    } catch (_) {
      return null;
    }
  }

  /// Wipe a session's ephemeral key + derived key. After this, past traffic in
  /// that session can never be decrypted again (forward secrecy on disconnect).
  void endSession(String sessionId) {
    _ephemeral.remove(sessionId);
    _fsSessions.remove(sessionId);
  }

  Future<List<int>> _dh(SimpleKeyPair mine, SimplePublicKey peer) async {
    final shared =
        await _x25519.sharedSecretKey(keyPair: mine, remotePublicKey: peer);
    return shared.extractBytes();
  }

  int _compareBytes(List<int> a, List<int> b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) return a[i] - b[i];
    }
    return a.length - b.length;
  }

  /// Cryptographic safety code for a public key, for out-of-band MITM
  /// verification. Render on both phones; matching codes => no man-in-the-middle.
  ///
  /// This MUST be a cryptographic hash: an attacker who could brute-force a key
  /// whose code collides with the victim's could defeat verification entirely.
  /// We derive it from SHA-256 (80 bits shown ≈ 2^80 collision work), NOT a
  /// fast non-cryptographic hash.
  static Future<String> fingerprint(String publicKeyB64) async {
    if (publicKeyB64.isEmpty) return '---- ---- ----';
    final digest = await Sha256().hash(base64.decode(publicKeyB64));
    // First 10 bytes (80 bits) rendered as decimal, grouped like a safety number.
    var v = BigInt.zero;
    for (var i = 0; i < 10; i++) {
      v = (v << 8) | BigInt.from(digest.bytes[i]);
    }
    final digits = v.toString().padLeft(25, '0');
    final out = StringBuffer();
    for (var i = 0; i < 25; i += 5) {
      if (i > 0) out.write(' ');
      out.write(digits.substring(i, i + 5));
    }
    return out.toString();
  }

  void clearSessions() {
    _sessionCache.clear();
    _ephemeral.clear();
    _fsSessions.clear();
  }
}
