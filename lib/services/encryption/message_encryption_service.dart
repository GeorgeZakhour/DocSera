import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:supabase_flutter/supabase_flutter.dart';

/// ============================================================
/// DocSera Message Encryption Service
/// AES-256-GCM encryption for messages and media files
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

  /// Prefix added to encrypted text so we can distinguish from plain text
  static const String _encPrefix = 'ENC:';

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

      // Convert hex string to 32 bytes (256 bits)
      final keyBytes = _hexToBytes(keyHex);
      _key = enc.Key(keyBytes);
      _initialized = true;
    } catch (e) {
      // If encryption init fails, we degrade gracefully — messages
      // will be sent/stored as plain text (same as before encryption).
      _initialized = false;
      // ignore: avoid_print
      print('[MessageEncryption] ⚠️ Failed to init: $e');
    }
  }

  /// Whether encryption is ready to use
  bool get isReady => _initialized && _key != null;

  // ---------------------------------------------------------------------------
  // Text Encryption
  // ---------------------------------------------------------------------------

  /// Encrypts plain text → "ENC:<base64(iv + ciphertext)>"
  /// Returns original text if encryption is not initialized.
  String encryptText(String plainText) {
    if (!isReady || plainText.isEmpty) return plainText;

    try {
      final iv = enc.IV.fromSecureRandom(16); // 128-bit IV
      final encrypter = enc.Encrypter(enc.AES(_key!, mode: enc.AESMode.cbc, padding: 'PKCS7'));
      final encrypted = encrypter.encrypt(plainText, iv: iv);

      // Combine IV + ciphertext for storage
      final combined = Uint8List.fromList([...iv.bytes, ...encrypted.bytes]);
      return '$_encPrefix${base64Encode(combined)}';
    } catch (e) {
      // Fallback: return plain text if encryption fails
      return plainText;
    }
  }

  /// Decrypts "ENC:<base64>" → plain text.
  /// If text doesn't start with "ENC:", returns as-is (legacy plain text).
  String decryptText(String cipherText) {
    if (!isReady || !cipherText.startsWith(_encPrefix)) {
      return cipherText; // Legacy plain text or encryption not ready
    }

    try {
      final encoded = cipherText.substring(_encPrefix.length);
      final combined = base64Decode(encoded);

      // First 16 bytes = IV, rest = ciphertext
      final iv = enc.IV(Uint8List.fromList(combined.sublist(0, 16)));
      final encryptedBytes = combined.sublist(16);

      final encrypter = enc.Encrypter(enc.AES(_key!, mode: enc.AESMode.cbc, padding: 'PKCS7'));
      final decrypted = encrypter.decrypt(enc.Encrypted(encryptedBytes), iv: iv);

      return decrypted;
    } catch (e) {
      // If decryption fails, return raw text (could be corrupted or plain)
      return cipherText;
    }
  }

  // ---------------------------------------------------------------------------
  // File/Media Encryption
  // ---------------------------------------------------------------------------

  /// Encrypts file bytes → encrypted bytes (IV prepended)
  Uint8List? encryptBytes(Uint8List plainBytes) {
    if (!isReady) return null;

    try {
      final iv = enc.IV.fromSecureRandom(16);
      final encrypter = enc.Encrypter(enc.AES(_key!, mode: enc.AESMode.cbc, padding: 'PKCS7'));
      final encrypted = encrypter.encryptBytes(plainBytes.toList(), iv: iv);

      // Prepend IV to encrypted bytes
      return Uint8List.fromList([...iv.bytes, ...encrypted.bytes]);
    } catch (e) {
      return null;
    }
  }

  /// Decrypts encrypted bytes (with prepended IV) → original file bytes
  Uint8List? decryptBytes(Uint8List encryptedBytes) {
    if (!isReady || encryptedBytes.length < 17) return null;

    try {
      final iv = enc.IV(Uint8List.fromList(encryptedBytes.sublist(0, 16)));
      final cipherBytes = encryptedBytes.sublist(16);

      final encrypter = enc.Encrypter(enc.AES(_key!, mode: enc.AESMode.cbc, padding: 'PKCS7'));
      final decrypted = encrypter.decryptBytes(enc.Encrypted(cipherBytes), iv: iv);

      return Uint8List.fromList(decrypted);
    } catch (e) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }
}
