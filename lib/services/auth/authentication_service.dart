import 'package:firebase_auth/firebase_auth.dart';

class AuthenticationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// **Login with Email & Password**
  Future<User?> login(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user; // ✅ Login successful
    } catch (e) {
      print("❌ Login failed: $e");
      return null;
    }
  }

  /// **Register a New User in Firebase Authentication**
  Future<User?> register(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print("❌ Registration failed: $e");
      return null;
    }
  }

  /// **Get Currently Logged-in User**
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// **Logout User**
  Future<void> logout() async {
    await _auth.signOut();
  }
}
