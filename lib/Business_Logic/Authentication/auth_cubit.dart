import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_state.dart';

typedef RealtimeStarter = void Function(User user);
typedef RealtimeStopper = void Function();

class AuthCubit extends Cubit<AppAuthState> {
  final SupabaseClient _supabase;
  final SharedPreferences _prefs; // Make non-nullable
  StreamSubscription<AuthState>? _authSubscription;
  Timer? _sessionRefreshTimer;

  /// يتم حقنها من main.dart
  RealtimeStarter? onRealtimeStart;
  RealtimeStopper? onRealtimeStop;

  AuthCubit({SupabaseClient? supabase, required SharedPreferences prefs})
      : _supabase = supabase ?? Supabase.instance.client,
        _prefs = prefs,
        super(AuthInitial()) {
    _init();
  }

  // ---------------------------------------------------------------------------
  // INIT
  // ---------------------------------------------------------------------------
  Future<void> _init() async {
    emit(AuthLoading());
    // _prefs is already initialized via constructor

    _authSubscription =
        _supabase.auth.onAuthStateChange.listen(_onAuthStateChanged,
            onError: (error) {
              emit(AuthError("Auth stream error: $error"));
            });

    // 🔹 حالة التطبيق عند الإقلاع
    final session = _supabase.auth.currentSession;
    final user = session?.user;
    if (user != null) {
      emit(AuthAuthenticated(user));
      await _persistLogin(user.id);
      onRealtimeStart?.call(user);
    } else {
      emit(AuthUnauthenticated());
      await _clearLogin();
    }

    // 🔁 Auto refresh JWT to avoid InvalidJWTToken
    _sessionRefreshTimer = Timer.periodic(
      const Duration(minutes: 10), // 10–15 دقيقة مثالي
          (_) async {
        final session = _supabase.auth.currentSession;
        if (session == null) return;

        try {
          await _supabase.auth.refreshSession();
          // ⛔ لا تعمل emit هنا
          // tokenRefreshed سيُطلق onAuthStateChange تلقائيًا
        } catch (_) {
          // تجاهل بصمت
        }
      },
    );

  }

  // ---------------------------------------------------------------------------
  // AUTH STATE HANDLER (المكان الوحيد للتعامل مع JWT)
  // ---------------------------------------------------------------------------
  Future<void> _onAuthStateChanged(AuthState event) async {
    final session = event.session;
    final user = session?.user;

    switch (event.event) {
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.tokenRefreshed:
        if (user != null) {
          emit(AuthAuthenticated(user));
          await _persistLogin(user.id);

          // 🔁 إعادة تشغيل realtime (حل InvalidJWTToken)
          onRealtimeStart?.call(user);
        }
        break;

      case AuthChangeEvent.signedOut:
      case AuthChangeEvent.userDeleted:
        onRealtimeStop?.call();
        emit(AuthUnauthenticated());
        await _clearLogin();
        break;

      case AuthChangeEvent.passwordRecovery:
      case AuthChangeEvent.userUpdated:
        if (user != null) {
          emit(AuthAuthenticated(user));
          await _persistLogin(user.id);
        }
        break;

      default:
      // ignore
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // PUBLIC AUTH ACTIONS
  // ---------------------------------------------------------------------------
  Future<void> signInWithEmailAndPassword(
      String email,
      String password,
      ) async {
    try {
      emit(AuthLoading());
      final res = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.user == null) {
        emit(AuthError("Login failed: No user returned"));
      }
    } on AuthException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(AuthError("Unexpected login error: $e"));
    }
  }

  Future<void> signUpWithEmailAndPassword(
      String email,
      String password,
      ) async {
    try {
      emit(AuthLoading());
      final res = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (res.user == null) {
        emit(AuthError("Sign up failed: No user returned"));
      }
    } on AuthException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(AuthError("Unexpected sign up error: $e"));
    }
  }

  Future<void> signOut() async {
    try {
      onRealtimeStop?.call(); // ⛔ أوقف realtime فورًا
      await _supabase.auth.signOut();
    } catch (e) {
      emit(AuthError("Sign out error: $e"));
    }
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------
  Future<void> _persistLogin(String userId) async {
    await _prefs.setBool('isLoggedIn', true);
    await _prefs.setString('userId', userId);
  }

  Future<void> _clearLogin() async {
    await _prefs.setBool('isLoggedIn', false);
    await _prefs.remove('userId');
  }

  // ---------------------------------------------------------------------------
  // CLEANUP
  // ---------------------------------------------------------------------------
  @override
  Future<void> close() async {
    _sessionRefreshTimer?.cancel();
    await _authSubscription?.cancel();
    return super.close();
  }
}
