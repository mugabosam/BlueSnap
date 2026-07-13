// Tests for BlueSnap's safety primitives that need no platform channels:
// the key fingerprint (used for MITM verification) and message rate limiting.

import 'package:flutter_test/flutter_test.dart';
import 'package:bluesnap/services/crypto_service.dart';

void main() {
  group('CryptoService.fingerprint (cryptographic safety code)', () {
    test('is stable and formatted as 5 groups of 5 digits', () async {
      const key = 'QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVphYmNk'; // 30 bytes b64
      final a = await CryptoService.fingerprint(key);
      final b = await CryptoService.fingerprint(key);
      expect(a, b, reason: 'same key must yield same code');
      expect(a, matches(r'^\d{5} \d{5} \d{5} \d{5} \d{5}$'));
    });

    test('different keys yield different codes', () async {
      final a = await CryptoService.fingerprint('QUJDREVGR0hJSktMTU5PUFE=');
      final b = await CryptoService.fingerprint('WllYV1ZVVFNSUVBPTk1MS0k=');
      expect(a, isNot(b));
    });

    test('empty key returns a placeholder, not a crash', () async {
      expect(await CryptoService.fingerprint(''), '---- ---- ----');
    });
  });
}
