// CRITICAL — these tests guard the privacy claim of the entire app.
//
// MessageEncryptionService encrypts new chat messages and file bytes with
// AES-256-GCM (AEAD: confidentiality + integrity via a 128-bit auth tag).
// It also keeps a read-only decryption path for legacy AES-256-CBC + PKCS7
// blobs written by earlier builds, so old conversations stay readable.
//
// Regressions here mean either:
//   - Patient messages stored/transmitted in plaintext (privacy breach)
//   - Patient messages corrupted on decrypt (data loss)
//   - Tampered ciphertext silently accepted as authentic (integrity breach)
//   - Legacy CBC messages become unreadable (data loss for early users)
//
// We test through the public API using a test-injected key, so we
// exercise the actual production code paths.

import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_test/flutter_test.dart';

import 'package:docsera/services/encryption/message_encryption_service.dart';

Uint8List _testKey() => Uint8List.fromList(List<int>.generate(32, (i) => i));

Uint8List _otherKey() =>
    Uint8List.fromList(List<int>.generate(32, (i) => i + 100));

/// Manually produce a legacy CBC-encrypted text blob (`ENC:<base64(iv||ct)>`)
/// using the same conventions earlier builds used. Lets us verify the new
/// service can still read messages written before the GCM migration.
String _legacyCbcText(String plain, Uint8List keyBytes) {
  final iv = enc.IV.fromSecureRandom(16);
  final encrypter = enc.Encrypter(
    enc.AES(enc.Key(keyBytes), mode: enc.AESMode.cbc, padding: 'PKCS7'),
  );
  final encrypted = encrypter.encrypt(plain, iv: iv);
  final combined = Uint8List.fromList([...iv.bytes, ...encrypted.bytes]);
  return 'ENC:${base64Encode(combined)}';
}

/// Manually produce legacy CBC-encrypted bytes (`[iv(16)||ciphertext]`).
Uint8List _legacyCbcBytes(Uint8List plain, Uint8List keyBytes) {
  final iv = enc.IV.fromSecureRandom(16);
  final encrypter = enc.Encrypter(
    enc.AES(enc.Key(keyBytes), mode: enc.AESMode.cbc, padding: 'PKCS7'),
  );
  final encrypted = encrypter.encryptBytes(plain.toList(), iv: iv);
  return Uint8List.fromList([...iv.bytes, ...encrypted.bytes]);
}

void main() {
  late MessageEncryptionService svc;

  setUp(() {
    svc = MessageEncryptionService.instance;
    svc.initWithKeyForTesting(_testKey());
  });

  tearDown(() => svc.resetForTesting());

  group('MessageEncryptionService — text encryption (GCM, new format)', () {
    test('round-trip recovers the original plaintext', () {
      const plain = 'hello world from a patient';
      final cipher = svc.encryptText(plain);
      expect(cipher, startsWith('ENCv2:'));
      expect(svc.decryptText(cipher), plain);
    });

    test('round-trip preserves Arabic / RTL text', () {
      const plain = 'مرحبا، كيف حالك يا دكتور؟';
      final cipher = svc.encryptText(plain);
      expect(svc.decryptText(cipher), plain);
    });

    test('round-trip preserves emoji and 4-byte UTF-8', () {
      const plain = '🩺💊 patient feels 😀';
      final cipher = svc.encryptText(plain);
      expect(svc.decryptText(cipher), plain);
    });

    test('round-trip preserves multi-line content', () {
      const plain = 'line1\nline2\n\nline4';
      final cipher = svc.encryptText(plain);
      expect(svc.decryptText(cipher), plain);
    });

    test('two encryptions of the same plaintext produce different ciphertexts',
        () {
      // Nonce is randomised per call → semantic security.
      final a = svc.encryptText('same');
      final b = svc.encryptText('same');
      expect(a, isNot(equals(b)));
      expect(svc.decryptText(a), 'same');
      expect(svc.decryptText(b), 'same');
    });

    test('empty string is a no-op (returned as-is)', () {
      expect(svc.encryptText(''), '');
      expect(svc.decryptText(''), '');
    });

    test('decryptText on legacy plain text returns it unchanged', () {
      expect(svc.decryptText('legacy plain text'), 'legacy plain text');
    });

    test('decrypt of garbage ENCv2: payload returns the raw text (no crash)',
        () {
      final result = svc.decryptText('ENCv2:not-base64-at-all!!!');
      expect(result, 'ENCv2:not-base64-at-all!!!');
    });

    test('decrypt with WRONG key fails-soft (does not return original plaintext)',
        () {
      final cipher = svc.encryptText('secret');
      svc.resetForTesting();
      svc.initWithKeyForTesting(_otherKey());
      final result = svc.decryptText(cipher);
      // GCM auth tag check must fail — service returns the cipher text
      // unchanged. Critically, must NOT return the original plaintext.
      expect(result, isNot(equals('secret')));
    });

    test('tampered GCM ciphertext fails the auth check (returns cipher unchanged)',
        () {
      final cipher = svc.encryptText('authentic message');
      // Flip one bit in the base64 payload — this corrupts a byte in
      // either nonce, ciphertext, or auth tag depending on position.
      final tampered =
          '${cipher.substring(0, cipher.length - 4)}AAAA';
      final result = svc.decryptText(tampered);
      expect(result, isNot(equals('authentic message')));
    });

    test('decrypt of truncated payload does not crash', () {
      final cipher = svc.encryptText('long enough message');
      final truncated = cipher.substring(0, cipher.length - 5);
      final result = svc.decryptText(truncated);
      expect(result, isA<String>());
    });

    test('encrypted payload base64 segment includes nonce + tag overhead',
        () {
      final cipher = svc.encryptText('x');
      final b64 = cipher.substring('ENCv2:'.length);
      final bytes = base64Decode(b64);
      // Minimum: 12-byte nonce + 1 byte ciphertext + 16-byte tag = 29 bytes.
      expect(bytes.length, greaterThanOrEqualTo(29));
    });

    test('returns plain text when service is not initialized', () {
      svc.resetForTesting();
      expect(svc.encryptText('hello'), 'hello');
      expect(svc.decryptText('ENCv2:abc'), 'ENCv2:abc');
      expect(svc.decryptText('ENC:abc'), 'ENC:abc');
    });
  });

  group(
      'MessageEncryptionService — text decryption (CBC backward compat)',
      () {
    test('decrypts legacy ENC: (CBC) blobs with the same key', () {
      final blob = _legacyCbcText('legacy message', _testKey());
      expect(blob, startsWith('ENC:'));
      expect(svc.decryptText(blob), 'legacy message');
    });

    test('decrypts legacy CBC Arabic content', () {
      final blob = _legacyCbcText('رسالة قديمة من قبل التحديث', _testKey());
      expect(svc.decryptText(blob), 'رسالة قديمة من قبل التحديث');
    });

    test('legacy CBC with wrong key fails-soft (no plaintext leak)', () {
      final blob = _legacyCbcText('legacy secret', _otherKey());
      // Service is initialised with _testKey() in setUp, so this can't decrypt.
      final result = svc.decryptText(blob);
      expect(result, isNot(equals('legacy secret')));
    });

    test('garbage ENC: payload returns the raw text (no crash)', () {
      final result = svc.decryptText('ENC:not-base64-either!');
      expect(result, 'ENC:not-base64-either!');
    });
  });

  group('MessageEncryptionService — bytes encryption (GCM, new format)', () {
    test('round-trip recovers original bytes', () {
      final plain =
          Uint8List.fromList(List<int>.generate(256, (i) => i % 256));
      final cipher = svc.encryptBytes(plain);
      expect(cipher, isNotNull);
      expect(cipher!.length, greaterThan(plain.length));
      final back = svc.decryptBytes(cipher);
      expect(back, isNotNull);
      expect(back, equals(plain));
    });

    test('new bytes ciphertext begins with the ENCv2: magic header', () {
      final plain = Uint8List.fromList([1, 2, 3, 4, 5]);
      final cipher = svc.encryptBytes(plain)!;
      final magic = utf8.encode('ENCv2:');
      expect(cipher.sublist(0, magic.length), equals(magic));
    });

    test('encryptBytes returns null when service not initialized', () {
      svc.resetForTesting();
      final result = svc.encryptBytes(Uint8List.fromList([1, 2, 3]));
      expect(result, isNull);
    });

    test('decryptBytes returns null when service not initialized', () {
      svc.resetForTesting();
      final result = svc.decryptBytes(Uint8List.fromList(List.filled(64, 0)));
      expect(result, isNull);
    });

    test('decryptBytes returns null for too-short legacy CBC input (<17 bytes)',
        () {
      // No magic header → routed to legacy CBC path → needs IV(16)+>=1 byte.
      final result = svc.decryptBytes(Uint8List.fromList([1, 2, 3]));
      expect(result, isNull);
    });

    test('decryptBytes returns null for too-short GCM input', () {
      // Magic header present but not enough bytes for nonce + tag.
      final magic = utf8.encode('ENCv2:');
      final tooShort = Uint8List.fromList([...magic, 1, 2, 3]);
      expect(svc.decryptBytes(tooShort), isNull);
    });

    test('decryptBytes with wrong key returns null (GCM tag check fails)', () {
      final plain = Uint8List.fromList([10, 20, 30, 40]);
      final cipher = svc.encryptBytes(plain)!;
      svc.resetForTesting();
      svc.initWithKeyForTesting(_otherKey());
      final result = svc.decryptBytes(cipher);
      expect(result, isNull);
    });

    test('tampered GCM bytes return null (no silent corruption)', () {
      final plain = Uint8List.fromList(List<int>.generate(64, (i) => i));
      final cipher = svc.encryptBytes(plain)!;
      // Flip a bit somewhere in the ciphertext region.
      final tampered = Uint8List.fromList(cipher);
      tampered[cipher.length - 5] ^= 0xFF;
      expect(svc.decryptBytes(tampered), isNull);
    });

    test('encryptBytes produces different ciphertexts for same plaintext (random nonce)',
        () {
      final plain = Uint8List.fromList([1, 2, 3, 4, 5]);
      final a = svc.encryptBytes(plain)!;
      final b = svc.encryptBytes(plain)!;
      expect(a, isNot(equals(b)));
      expect(svc.decryptBytes(a), equals(plain));
      expect(svc.decryptBytes(b), equals(plain));
    });
  });

  group(
      'MessageEncryptionService — bytes decryption (CBC backward compat)',
      () {
    test('decrypts legacy CBC byte streams (no magic header) with same key', () {
      final plain = Uint8List.fromList([0xAA, 0xBB, 0xCC, 0xDD, 0xEE]);
      final blob = _legacyCbcBytes(plain, _testKey());
      // Sanity: legacy format has no magic header — first 16 bytes are IV.
      final magic = utf8.encode('ENCv2:');
      expect(
        blob.sublist(0, magic.length),
        isNot(equals(magic)),
        reason: 'legacy CBC bytes should not collide with the GCM magic',
      );
      expect(svc.decryptBytes(blob), equals(plain));
    });

    test('legacy CBC bytes with wrong key do not return original bytes', () {
      final plain = Uint8List.fromList([10, 20, 30, 40]);
      final blob = _legacyCbcBytes(plain, _otherKey());
      final result = svc.decryptBytes(blob);
      if (result != null) {
        expect(result, isNot(equals(plain)));
      }
    });
  });

  group('MessageEncryptionService — singleton + lifecycle', () {
    test('instance getter is stable across calls', () {
      final a = MessageEncryptionService.instance;
      final b = MessageEncryptionService.instance;
      expect(identical(a, b), true);
    });

    test('isReady reflects key presence', () {
      expect(svc.isReady, true);
      svc.resetForTesting();
      expect(svc.isReady, false);
      svc.initWithKeyForTesting(_testKey());
      expect(svc.isReady, true);
    });

    test('initWithKeyForTesting asserts key length', () {
      svc.resetForTesting();
      expect(
        () => svc.initWithKeyForTesting(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
