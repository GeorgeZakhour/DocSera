// CRITICAL — these tests guard the privacy claim of the entire app.
//
// MessageEncryptionService encrypts chat messages and file bytes with
// AES-256-CBC + PKCS7. Regressions here mean either:
//   - Patient messages stored/transmitted in plaintext (privacy breach)
//   - Patient messages corrupted on decrypt (data loss)
//   - Tampered ciphertext silently accepted (integrity breach)
//
// We test through the public API using a test-injected key, so we
// exercise the actual production code paths.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:docsera/services/encryption/message_encryption_service.dart';

Uint8List _testKey() => Uint8List.fromList(List<int>.generate(32, (i) => i));

Uint8List _otherKey() =>
    Uint8List.fromList(List<int>.generate(32, (i) => i + 100));

void main() {
  late MessageEncryptionService svc;

  setUp(() {
    svc = MessageEncryptionService.instance;
    svc.initWithKeyForTesting(_testKey());
  });

  tearDown(() => svc.resetForTesting());

  group('MessageEncryptionService — text encryption', () {
    test('round-trip recovers the original plaintext', () {
      const plain = 'hello world from a patient';
      final cipher = svc.encryptText(plain);
      expect(cipher, startsWith('ENC:'));
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
      // IV is randomized per call → semantic security.
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
      // Messages from before encryption was deployed have no ENC: prefix
      // and must keep rendering correctly.
      expect(svc.decryptText('legacy plain text'), 'legacy plain text');
    });

    test('decrypt of garbage ENC: payload returns the raw text (no crash)',
        () {
      // Hostile or corrupted payload — must not throw, must not silently
      // succeed with wrong content.
      final result = svc.decryptText('ENC:not-base64-at-all!!!');
      expect(result, 'ENC:not-base64-at-all!!!');
    });

    test('decrypt with WRONG key produces non-plaintext (tamper detection)',
        () {
      final cipher = svc.encryptText('secret');
      // Re-init with a different key.
      svc.resetForTesting();
      svc.initWithKeyForTesting(_otherKey());
      final result = svc.decryptText(cipher);
      // Either error path returns the cipher text unchanged, OR returns
      // garbage bytes interpreted as text. Critically: it must NOT
      // return the original plaintext.
      expect(result, isNot(equals('secret')));
    });

    test('decrypt of truncated payload does not crash', () {
      final cipher = svc.encryptText('long enough message');
      // Chop off some bytes → must fail-soft.
      final truncated = cipher.substring(0, cipher.length - 5);
      final result = svc.decryptText(truncated);
      // Either returns raw or fails-soft; must not crash.
      expect(result, isA<String>());
    });

    test('encrypted payload base64 segment decodes to >= 17 bytes (IV + at least 1 cipher byte)',
        () {
      final cipher = svc.encryptText('x');
      final b64 = cipher.substring('ENC:'.length);
      final bytes = base64Decode(b64);
      expect(bytes.length, greaterThanOrEqualTo(17));
    });

    test('returns plain text when service is not initialized', () {
      svc.resetForTesting();
      expect(svc.encryptText('hello'), 'hello');
      expect(svc.decryptText('ENC:abc'), 'ENC:abc');
    });
  });

  group('MessageEncryptionService — bytes encryption (file/media)', () {
    test('round-trip recovers original bytes', () {
      final plain = Uint8List.fromList(List<int>.generate(256, (i) => i % 256));
      final cipher = svc.encryptBytes(plain);
      expect(cipher, isNotNull);
      expect(cipher!.length, greaterThan(plain.length)); // IV + padding
      final back = svc.decryptBytes(cipher);
      expect(back, isNotNull);
      expect(back, equals(plain));
    });

    test('encryptBytes returns null when service not initialized', () {
      svc.resetForTesting();
      final result = svc.encryptBytes(Uint8List.fromList([1, 2, 3]));
      expect(result, isNull);
    });

    test('decryptBytes returns null when service not initialized', () {
      svc.resetForTesting();
      final result = svc.decryptBytes(Uint8List.fromList(List.filled(32, 0)));
      expect(result, isNull);
    });

    test('decryptBytes returns null for too-short input (<17 bytes)', () {
      // Less than IV(16) + 1 byte ciphertext.
      final result = svc.decryptBytes(Uint8List.fromList([1, 2, 3]));
      expect(result, isNull);
    });

    test('decryptBytes with wrong key does not return original bytes', () {
      final plain = Uint8List.fromList([10, 20, 30, 40]);
      final cipher = svc.encryptBytes(plain)!;

      svc.resetForTesting();
      svc.initWithKeyForTesting(_otherKey());
      final result = svc.decryptBytes(cipher);
      // PKCS7 padding will likely throw → null. If it doesn't, the
      // bytes must not match the original.
      if (result != null) {
        expect(result, isNot(equals(plain)));
      }
    });

    test('encryptBytes produces different ciphertexts for same plaintext (random IV)',
        () {
      final plain = Uint8List.fromList([1, 2, 3, 4, 5]);
      final a = svc.encryptBytes(plain)!;
      final b = svc.encryptBytes(plain)!;
      expect(a, isNot(equals(b)));
      expect(svc.decryptBytes(a), equals(plain));
      expect(svc.decryptBytes(b), equals(plain));
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
