/// BlueSnap app-lock authentication.
///
/// The app holds private messages and an identity key, so entry is gated by a
/// local secret the user sets — a PIN (salted SHA-256, stored in hardware-backed
/// secure storage) with optional device biometrics as a convenience unlock.
/// There is no server and no password check against one; this is a genuine
/// on-device lock, not the old "any password works" placeholder.
library;

import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class AuthService {
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;
  AuthService._();

  static const _pinHashKey = 'auth_pin_hash_v1';
  static const _pinSaltKey = 'auth_pin_salt_v1';
  static const _biometricPrefKey = 'auth_biometric_enabled_v1';
  static const _failCountKey = 'auth_fail_count_v1';
  static const _lockUntilKey = 'auth_lock_until_v1';

  // A short PIN has a tiny keyspace, so make each guess expensive (PBKDF2) and
  // throttle online guessing (lockout after repeated failures).
  static const _pbkdf2Iterations = 60000;
  static const _freeAttempts = 5; // no lockout for the first few honest typos

  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final LocalAuthentication _localAuth = LocalAuthentication();
  final _sha256 = Sha256();

  /// True once the user has set a PIN (i.e. an account exists on this device).
  Future<bool> hasPin() async {
    final h = await _secure.read(key: _pinHashKey);
    return h != null && h.isNotEmpty;
  }

  /// Create or replace the PIN. Minimum four digits enforced by the caller/UI.
  Future<void> setPin(String pin) async {
    final salt = _randomSalt();
    final hash = await _pbkdf2(pin, salt);
    await _secure.write(key: _pinSaltKey, value: base64.encode(salt));
    // "v2:" marks a PBKDF2 hash; legacy values (plain SHA-256) verify too.
    await _secure.write(key: _pinHashKey, value: 'v2:$hash');
    await _resetFailures();
  }

  /// Remaining lockout, or Duration.zero if entry is currently allowed.
  Future<Duration> lockoutRemaining() async {
    final until = int.tryParse(await _secure.read(key: _lockUntilKey) ?? '');
    if (until == null) return Duration.zero;
    final ms = until - DateTime.now().millisecondsSinceEpoch;
    return ms > 0 ? Duration(milliseconds: ms) : Duration.zero;
  }

  /// Verify a PIN. Enforces a lockout that grows with repeated failures so the
  /// small PIN space can't be brute-forced by hammering the lock screen.
  Future<bool> verifyPin(String pin) async {
    if ((await lockoutRemaining()) > Duration.zero) return false;

    final saltB64 = await _secure.read(key: _pinSaltKey);
    final stored = await _secure.read(key: _pinHashKey);
    if (saltB64 == null || stored == null) return false;
    final salt = base64.decode(saltB64);

    final bool ok;
    if (stored.startsWith('v2:')) {
      final candidate = await _pbkdf2(pin, salt);
      ok = _constantTimeEquals(candidate, stored.substring(3));
    } else {
      // Legacy single-round SHA-256 hash — verify, then transparently upgrade.
      final legacy = await _legacyHash(pin, salt);
      ok = _constantTimeEquals(legacy, stored);
      if (ok) await setPin(pin); // re-hash with PBKDF2 on next successful entry
    }

    if (ok) {
      await _resetFailures();
      return true;
    }
    await _recordFailure();
    return false;
  }

  Future<void> _recordFailure() async {
    final count = (int.tryParse(await _secure.read(key: _failCountKey) ?? '0') ?? 0) + 1;
    await _secure.write(key: _failCountKey, value: '$count');
    if (count >= _freeAttempts) {
      // Escalating lockout: 30s, 1m, 2m, 5m, 15m (capped).
      final over = count - _freeAttempts;
      const steps = [30, 60, 120, 300, 900];
      final secs = steps[over.clamp(0, steps.length - 1)];
      final until = DateTime.now().add(Duration(seconds: secs)).millisecondsSinceEpoch;
      await _secure.write(key: _lockUntilKey, value: '$until');
    }
  }

  Future<void> _resetFailures() async {
    await _secure.delete(key: _failCountKey);
    await _secure.delete(key: _lockUntilKey);
  }

  // ── Biometrics ─────────────────────────────────────────
  Future<bool> get biometricsAvailable async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  Future<bool> get biometricEnabled async =>
      (await _secure.read(key: _biometricPrefKey)) == 'true';

  Future<void> setBiometricEnabled(bool enabled) =>
      _secure.write(key: _biometricPrefKey, value: enabled ? 'true' : 'false');

  /// Prompt the device biometric sheet. Returns true on success.
  Future<bool> authenticateBiometric() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Unlock BlueSnap',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      debugPrint('[Auth] Biometric failed: $e');
      return false;
    }
  }

  // ── Internals ──────────────────────────────────────────
  /// Slow, salted key derivation — makes each PIN guess cost ~100ms, so even
  /// the full 4-digit space takes hours to brute-force (vs. microseconds).
  Future<String> _pbkdf2(String pin, List<int> salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pbkdf2Iterations,
      bits: 256,
    );
    final key = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
    return base64.encode(await key.extractBytes());
  }

  /// Legacy single-round SHA-256 hash (for verifying PINs set by older builds).
  Future<String> _legacyHash(String pin, List<int> salt) async {
    final mac = await _sha256.hash([...salt, ...utf8.encode(pin)]);
    return base64.encode(mac.bytes);
  }

  List<int> _randomSalt() {
    final rng = Random.secure();
    return List<int>.generate(16, (_) => rng.nextInt(256));
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
