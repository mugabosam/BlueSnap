// Tests the X25519 + AES-GCM primitives that back BlueSnap's E2E encryption.
// These exercise the `cryptography` package directly (no Hive/Flutter needed),
// mirroring exactly what CryptoService does on the wire.

import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final x25519 = X25519();
  final aes = AesGcm.with256bits();

  Future<SecretKey> sessionKey(
      SimpleKeyPair mine, SimplePublicKey theirs) async {
    final shared =
        await x25519.sharedSecretKey(keyPair: mine, remotePublicKey: theirs);
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    return hkdf.deriveKey(
      secretKey: shared,
      info: utf8.encode('bluesnap-session-v1'),
    );
  }

  test('two parties derive the same session key (ECDH symmetry)', () async {
    final alice = await x25519.newKeyPair();
    final bob = await x25519.newKeyPair();
    final alicePub = await alice.extractPublicKey();
    final bobPub = await bob.extractPublicKey();

    final kA = await sessionKey(alice, bobPub);
    final kB = await sessionKey(bob, alicePub);

    expect(await kA.extractBytes(), equals(await kB.extractBytes()));
  });

  test('round-trips an encrypted message between two parties', () async {
    final alice = await x25519.newKeyPair();
    final bob = await x25519.newKeyPair();
    final keyForBob = await sessionKey(alice, await bob.extractPublicKey());
    final keyForAlice = await sessionKey(bob, await alice.extractPublicKey());

    const plaintext = 'meet at the market at noon';
    final box = await aes.encrypt(utf8.encode(plaintext), secretKey: keyForBob);
    final wire = base64.encode(box.concatenation());

    final restored = SecretBox.fromConcatenation(
      base64.decode(wire),
      nonceLength: 12,
      macLength: 16,
    );
    final clear = await aes.decrypt(restored, secretKey: keyForAlice);
    expect(utf8.decode(clear), plaintext);
  });

  test('tampered ciphertext fails authentication', () async {
    final alice = await x25519.newKeyPair();
    final bob = await x25519.newKeyPair();
    final key = await sessionKey(alice, await bob.extractPublicKey());

    final box = await aes.encrypt(utf8.encode('secret'), secretKey: key);
    final bytes = box.concatenation();
    bytes[bytes.length - 1] ^= 0xFF; // corrupt the GCM tag
    final tampered = SecretBox.fromConcatenation(bytes,
        nonceLength: 12, macLength: 16);

    expect(
      () async => aes.decrypt(tampered, secretKey: key),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  test('a wrong key cannot decrypt', () async {
    final alice = await x25519.newKeyPair();
    final bob = await x25519.newKeyPair();
    final eve = await x25519.newKeyPair();

    final keyAB = await sessionKey(alice, await bob.extractPublicKey());
    final keyAE = await sessionKey(alice, await eve.extractPublicKey());

    final box = await aes.encrypt(utf8.encode('private'), secretKey: keyAB);
    expect(
      () async => aes.decrypt(box, secretKey: keyAE),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });
}
