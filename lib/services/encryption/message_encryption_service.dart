import 'dart:convert';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ============================================================
/// DocSera Message Encryption Service
///
/// Encrypts new chat messages and file bytes with AES-256-GCM
/// (AEAD — confidentiality + a 128-bit auth tag for integrity).
///
/// Also keeps a read-only decryption path for AES-256-CBC + PKCS7
/// blobs written by earlier builds, so messages stored before the
/// GCM migration stay readable. New writes always use GCM.
///
///   Text format:   "ENCv2:<base64(nonce(12) || ciphertext || tag(16))>"
///   Bytes format:  [ascii("ENCv2:"), nonce(12), ciphertext, tag(16)]
///   Legacy text:   "ENC:<base64(iv(16) || ciphertext)>"   (CBC, decrypt-only)
///   Legacy bytes:  [iv(16), ciphertext]                    (CBC, decrypt-only)
///
/// Key material is fetched once from Supabase via `rpc_get_encryption_key`.
/// ============================================================
class MessageEncryptionService {
  static MessageEncryptionService? _instance;
  static MessageEncryptionService get instance {
    _instance ??= MessageEncryptionService._();
    return _instance!;
  }

  MessageEncryptionService._();

  enc.Key? _key;
  bool _initialized = false;

  /// Current text-format prefix — GCM, versioned for future algorithm changes.
  static const String _prefixV2 = 'ENCv2:';

  /// Legacy text-format prefix — CBC. Decrypted but never produced.
  static const String _prefixV1 = 'ENC:';

  /// Magic header on new byte-encoded blobs. Mirrors the text prefix so any
  /// payload not starting with these 6 ASCII bytes is treated as legacy CBC.
  static final Uint8List _bytesMagicV2 =
      Uint8List.fromList(utf8.encode(_prefixV2));

  /// GCM uses a 12-byte (96-bit) nonce per NIST SP 800-38D guidance.
  static const int _gcmNonceLength = 12;

  /// GCM authentication tag length (128 bits — appended to ciphertext).
  static const int _gcmTagLength = 16;

  /// CBC IV length (one AES block).
  static const int _cbcIvLength = 16;

  // ---------------------------------------------------------------------------
  // Initialization — fetch key from Supabase RPC (once)
  // ---------------------------------------------------------------------------
  Future<void> init() async {
    if (_initialized) return;

    try {
      final client = Supabase.instance.client;
      final String keyHex = await client.rpc('rpc_get_encryption_key');

      if (keyHex.isEmpty) {
        throw Exception('Encryption key is empty');
      }

      final keyBytes = _hexToBytes(keyHex);
      _key = enc.Key(keyBytes);
      _initialized = true;
    } catch (e) {
      // Fail-soft: messages flow as plain text rather than crashing the app.
      _initialized = false;
      if (kDebugMode) {
        // ignore: avoid_print
        print('[MessageEncryption] Failed to init: $e');
      }
    }
  }

  /// Whether encryption is ready to use.
  bool get isReady => _initialized && _key != null;

  /// Test-only: directly inject a 32-byte key without going through Supabase.
  /// Use [resetForTesting] in tearDown to undo.
  @visibleForTesting
  void initWithKeyForTesting(Uint8List keyBytes) {
    assert(keyBytes.length == 32, 'AES-256 key must be 32 bytes');
    _key = enc.Key(keyBytes);
    _initialized = true;
  }

  /// Test-only: revert to uninitialized state. Call in tearDown.
  @visibleForTesting
  void resetForTesting() {
    _key = null;
    _initialized = false;
  }

  /// Defensive: ensure the key is loaded before any decrypt/encrypt call.
  /// Safe to call multiple times — returns immediately if already initialized.
  Future<void> ensureReady() async {
    if (isReady) return;
    await init();
  }

  // ---------------------------------------------------------------------------
  // Text Encryption — always emits ENCv2: (GCM)
  // ---------------------------------------------------------------------------

  /// Encrypts plain text → "ENCv2:<base64(nonce || ciphertext || tag)>".
  /// Returns the original text untouched if encryption is unavailable.
  String encryptText(String plainText) {
    if (!isReady || plainText.isEmpty) return plainText;

    try {
      final iv = enc.IV.fromSecureRandom(_gcmNonceLength);
      final encrypter = enc.Encrypter(enc.AES(_key!, mode: enc.AESMode.gcm));
      final encrypted = encrypter.encrypt(plainText, iv: iv);

      // `encrypted.bytes` already includes the 16-byte GCM auth tag appended
      // to the ciphertext — see package:encrypt's AES GCM implementation.
      final combined =
          Uint8List.fromList([...iv.bytes, ...encrypted.bytes]);
      return '$_prefixV2${base64Encode(combined)}';
    } catch (_) {
      // Fail-soft: never block message send on a crypto error.
      return plainText;
    }
  }

  /// Decrypts an ENCv2: (GCM) blob or, for backward compat, an ENC: (CBC) blob.
  /// Returns the input unchanged when the prefix is not recognised (treated
  /// as legacy plain text), the service isn't initialised, or decryption fails.
  String decryptText(String cipherText) {
    if (!isReady) return cipherText;

    if (cipherText.startsWith(_prefixV2)) {
      return _decryptTextGcm(cipherText);
    }
    if (cipherText.startsWith(_prefixV1)) {
      return _decryptTextCbcLegacy(cipherText);
    }
    return cipherText;
  }

  String _decryptTextGcm(String cipherText) {
    try {
      final encoded = cipherText.substring(_prefixV2.length);
      final combined = base64Decode(encoded);
      if (combined.length < _gcmNonceLength + _gcmTagLength) {
        return cipherText;
      }
      final iv = enc.IV(
        Uint8List.fromList(combined.sublist(0, _gcmNonceLength)),
      );
      final cipherBytes = combined.sublist(_gcmNonceLength);
      final encrypter = enc.Encrypter(enc.AES(_key!, mode: enc.AESMode.gcm));
      return encrypter.decrypt(enc.Encrypted(cipherBytes), iv: iv);
    } catch (_) {
      return cipherText;
    }
  }

  String _decryptTextCbcLegacy(String cipherText) {
    try {
      final encoded = cipherText.substring(_prefixV1.length);
      final combined = base64Decode(encoded);
      if (combined.length < _cbcIvLength) return cipherText;
      final iv = enc.IV(
        Uint8List.fromList(combined.sublist(0, _cbcIvLength)),
      );
      final cipherBytes = combined.sublist(_cbcIvLength);
      final encrypter = enc.Encrypter(
        enc.AES(_key!, mode: enc.AESMode.cbc, padding: 'PKCS7'),
      );
      return encrypter.decrypt(enc.Encrypted(cipherBytes), iv: iv);
    } catch (_) {
      return cipherText;
    }
  }

  // ---------------------------------------------------------------------------
  // File / Media Encryption — always emits ENCv2:-magic-prefixed GCM bytes
  // ---------------------------------------------------------------------------

  /// Encrypts file bytes.
  ///   New layout: [magic("ENCv2:"), nonce(12), ciphertext, tag(16)]
  /// Returns null when the service isn't initialised or encryption fails.
  Uint8List? encryptBytes(Uint8List plainBytes) {
    if (!isReady) return null;

    try {
      final iv = enc.IV.fromSecureRandom(_gcmNonceLength);
      final encrypter = enc.Encrypter(enc.AES(_key!, mode: enc.AESMode.gcm));
      final encrypted =
          encrypter.encryptBytes(plainBytes.toList(), iv: iv);

      return Uint8List.fromList([
        ..._bytesMagicV2,
        ...iv.bytes,
        ...encrypted.bytes,
      ]);
    } catch (_) {
      return null;
    }
  }

  /// Decrypts bytes. Dispatches by the magic header:
  ///   * starts with "ENCv2:" → GCM path,
  ///   * otherwise           → legacy CBC path (16-byte IV prepended).
  /// Returns null on any failure (auth-tag mismatch, truncation, wrong key,
  /// uninitialized service).
  Uint8List? decryptBytes(Uint8List encryptedBytes) {
    if (!isReady) return null;

    if (_startsWithBytes(encryptedBytes, _bytesMagicV2)) {
      return _decryptBytesGcm(encryptedBytes);
    }
    return _decryptBytesCbcLegacy(encryptedBytes);
  }

  Uint8List? _decryptBytesGcm(Uint8List encryptedBytes) {
    final headerEnd = _bytesMagicV2.length;
    final minLen = headerEnd + _gcmNonceLength + _gcmTagLength;
    if (encryptedBytes.length < minLen) return null;

    try {
      final nonceEnd = headerEnd + _gcmNonceLength;
      final iv = enc.IV(
        Uint8List.fromList(encryptedBytes.sublist(headerEnd, nonceEnd)),
      );
      final cipherBytes = encryptedBytes.sublist(nonceEnd);
      final encrypter = enc.Encrypter(enc.AES(_key!, mode: enc.AESMode.gcm));
      final decrypted =
          encrypter.decryptBytes(enc.Encrypted(cipherBytes), iv: iv);
      return Uint8List.fromList(decrypted);
    } catch (_) {
      return null;
    }
  }

  Uint8List? _decryptBytesCbcLegacy(Uint8List encryptedBytes) {
    if (encryptedBytes.length < _cbcIvLength + 1) return null;

    try {
      final iv = enc.IV(
        Uint8List.fromList(encryptedBytes.sublist(0, _cbcIvLength)),
      );
      final cipherBytes = encryptedBytes.sublist(_cbcIvLength);
      final encrypter = enc.Encrypter(
        enc.AES(_key!, mode: enc.AESMode.cbc, padding: 'PKCS7'),
      );
      final decrypted =
          encrypter.decryptBytes(enc.Encrypted(cipherBytes), iv: iv);
      return Uint8List.fromList(decrypted);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static bool _startsWithBytes(Uint8List haystack, Uint8List needle) {
    if (haystack.length < needle.length) return false;
    for (var i = 0; i < needle.length; i++) {
      if (haystack[i] != needle[i]) return false;
    }
    return true;
  }

  Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }
}
