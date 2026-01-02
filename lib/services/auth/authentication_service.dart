import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  Future<void> logout() async {
    await _client.auth.signOut();
  }
}
