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
    final hash = await _hash(pin, salt);
    await _secure.write(key: _pinSaltKey, value: base64.encode(salt));
    await _secure.write(key: _pinHashKey, value: hash);
  }

  /// Verify an entered PIN against the stored salted hash (constant-time compare).
  Future<bool> verifyPin(String pin) async {
    final saltB64 = await _secure.read(key: _pinSaltKey);
    final stored = await _secure.read(key: _pinHashKey);
    if (saltB64 == null || stored == null) return false;
    final candidate = await _hash(pin, base64.decode(saltB64));
    return _constantTimeEquals(candidate, stored);
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
  Future<String> _hash(String pin, List<int> salt) async {
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
