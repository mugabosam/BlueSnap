// Tests for BlueSnap's safety primitives that need no platform channels:
// the key fingerprint (used for MITM verification) and message rate limiting.

import 'package:flutter_test/flutter_test.dart';
import 'package:bluesnap/services/crypto_service.dart';

void main() {
  group('CryptoService.fingerprint', () {
    test('is stable and formatted as grouped digits', () {
      const key = 'QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVphYmNk'; // 30 bytes b64
      final a = CryptoService.fingerprint(key);
      final b = CryptoService.fingerprint(key);
      expect(a, b, reason: 'same key must yield same fingerprint');
      expect(a, matches(r'^\d{4} \d{4} \d{4}$'));
    });

    test('different keys yield different fingerprints', () {
      final a = CryptoService.fingerprint('QUJDREVGR0hJSktMTU5PUFE=');
      final b = CryptoService.fingerprint('WllYV1ZVVFNSUVBPTk1MS0k=');
      expect(a, isNot(b));
    });

    test('empty key returns a placeholder, not a crash', () {
      expect(CryptoService.fingerprint(''), '----');
    });
  });
}
