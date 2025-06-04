import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_state.dart';

/// يعتمد على FirebaseAuth authStateChanges ويخزن بعض المعلومات في SharedPreferences
class AuthCubit extends Cubit<AuthState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final StreamSubscription<User?> _authSubscription;
  late SharedPreferences _prefs;

  AuthCubit() : super(AuthInitial()) {
    _init();
  }

  Future<void> _init() async {
    emit(AuthLoading()); // ✅ بدل AuthInitial، خليها Loading لنعرف أنه لسا بجهز
    _prefs = await SharedPreferences.getInstance();

    _authSubscription = _auth.authStateChanges().listen(
          (User? user) async {
        if (user == null) {
          // ✅ فقط لما نتاكد انو Firebase رد، نرجع Unauthenticated
          emit(AuthUnauthenticated());
          await _prefs.setBool('isLoggedIn', false);
          await _prefs.remove('userId');
        } else {
          emit(AuthAuthenticated(user));
          await _prefs.setBool('isLoggedIn', true);
          await _prefs.setString('userId', user.uid);
        }
      },
      onError: (error) {
        emit(AuthError("Auth State Stream Error: $error"));
      },
    );
  }


  /// تسجيل الدخول بالبريد وكلمة المرور (مثال)
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      emit(AuthLoading());
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      // لا نطلق AuthAuthenticated هنا؛ لأنّ authStateChanges() سيتكفّل بإطلاقها
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_handleFirebaseAuthError(e)));
    } catch (e) {
      emit(AuthError("Unexpected signIn error: $e"));
    }
  }

  /// إنشاء حساب جديد بالبريد وكلمة المرور (مثال)
  Future<void> signUpWithEmailAndPassword(String email, String password) async {
    try {
      emit(AuthLoading());
      UserCredential credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      // يتم إطلاق AuthAuthenticated تلقائيًا من authStateChanges()
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_handleFirebaseAuthError(e)));
    } catch (e) {
      emit(AuthError("Unexpected signUp error: $e"));
    }
  }

  /// تسجيل الخروج
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      // سيُطلق سطر user==null => AuthUnauthenticated
    } catch (e) {
      emit(AuthError("Sign out error: $e"));
    }
  }

  /// دالة داخلية لمعالجة أخطاء FirebaseAuthException
  String _handleFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return "Invalid email format.";
      case 'user-disabled':
        return "User is disabled.";
      case 'user-not-found':
        return "No user found for this email.";
      case 'wrong-password':
        return "Wrong password.";
      case 'email-already-in-use':
        return "Email already in use.";
      case 'weak-password':
        return "Weak password.";
      default:
        return "FirebaseAuth error: ${e.message}";
    }
  }

  /// إلغاء الاستماع لتغييرات الحالة عند إغلاق الكيوبت
  @override
  Future<void> close() {
    _authSubscription.cancel();
    return super.close();
  }
}
