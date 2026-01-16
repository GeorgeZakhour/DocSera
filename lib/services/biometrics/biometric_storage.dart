import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:docsera/services/storage/secure_storage_service.dart';

class BiometricStorage {
  static const _keyEnabled = 'enableFaceID';
  static const _keyEmail = 'biometric_login';
  static const _keyPassword = 'userPassword';
  
  static const _secureStorage = SecureStorageService();

  static Future<void> saveCredentials({
    required String email,
    required String password,
  }) async {
    try {
      // Save to Secure Storage
      await _secureStorage.write(key: _keyEmail, value: email);
      await _secureStorage.write(key: _keyPassword, value: password);
    } catch (e) {
      debugPrint("❌ [BiometricStorage] Failed to save to Secure Storage: $e");
    }
    
    // Ensure we clean up any old insecure copies
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_keyEmail)) await prefs.remove(_keyEmail);
    if (prefs.containsKey(_keyPassword)) await prefs.remove(_keyPassword);
  }

  static Future<void> clearCredentials() async {
    await _secureStorage.delete(key: _keyEmail);
    await _secureStorage.delete(key: _keyPassword);
    
    // Also clear from SharedPreferences just in case
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyPassword);
  }

  static Future<Map<String, String>?> getCredentials() async {
    // 1. Try to read from Secure Storage
    try {
      String? email = await _secureStorage.read(key: _keyEmail);
      String? password = await _secureStorage.read(key: _keyPassword);

      // 2. If present in Secure Storage, return them
      if (email != null && password != null) {
        return {'email': email, 'password': password};
      }
    } catch (e) {
      debugPrint("❌ [BiometricStorage] Error reading from Secure Storage: $e");
    }

    // 3. MIGRATION: Check SharedPreferences if not found in Secure Storage
    final prefs = await SharedPreferences.getInstance();
    final legacyEmail = prefs.getString(_keyEmail);
    final legacyPassword = prefs.getString(_keyPassword);

    if (legacyEmail != null && legacyPassword != null) {
      // Found legacy credentials! Migrate them to Secure Storage.
      await saveCredentials(email: legacyEmail, password: legacyPassword);
      return {'email': legacyEmail, 'password': legacyPassword};
    }

    return null;
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? false;
  }
}
