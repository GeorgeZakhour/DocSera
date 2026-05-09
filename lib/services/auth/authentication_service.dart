import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:docsera/services/notifications/notification_service.dart';

class AuthenticationService {
  final SupabaseClient _client = Supabase.instance.client;

  /// **Login with Email & Password**
  Future<AuthResponse?> login(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      debugPrint("❌ Login failed: $e");
      return null;
    }
  }

  /// **Register a New User in Supabase Auth**
  Future<AuthResponse?> register(String email, String password) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      debugPrint("❌ Registration failed: $e");
      return null;
    }
  }

  /// **Get Currently Logged-in User**
  User? getCurrentUser() {
    return _client.auth.currentUser;
  }

  /// **Logout User**
  ///
  /// Drops this device's user_devices row before terminating the session.
  /// Without that, notifications for the just-logged-out user keep
  /// firing on the physical device after another user signs in on it.
  /// RLS scopes the delete to the current user's own rows.
  Future<void> logout() async {
    try {
      await NotificationService.instance.deleteToken();
    } catch (e) {
      debugPrint('⚠️ AuthenticationService.logout: deleteToken failed: $e');
    }
    await _client.auth.signOut();
  }
}
