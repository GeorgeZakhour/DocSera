import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:docsera/services/notifications/notification_service.dart';
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
      await _resolveAuthState(user);
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
          await _resolveAuthState(user);
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
          await _resolveAuthState(user);
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
      // Drop this device's user_devices row first so the just-signed-out
      // user's notifications stop firing on this physical device after
      // someone else signs in.
      try {
        await NotificationService.instance.deleteToken();
      } catch (_) { /* best effort */ }
      await _supabase.auth.signOut();
    } catch (e) {
      emit(AuthError("Sign out error: $e"));
    }
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  /// Decides whether a Supabase session is "real enough" to be treated
  /// as authenticated. A bare auth.users row isn't enough — the
  /// patient app needs a matching `public.users` profile to function.
  /// Otherwise UserCubit and friends sit forever on shimmer skeletons.
  ///
  /// Orphan-session causes we've seen in this codebase:
  ///   * cross-app verify-and-signOut whose tokens lingered in
  ///     storage past the signOut call,
  ///   * an interrupted signup where atomic rollback wiped the profile
  ///     row but the device kept its session,
  ///   * an admin-deleted profile while the user's auth row stayed,
  ///   * any future bug that lands the app in the same shape.
  ///
  /// We probe the `users` table for a row matching auth.uid(). RLS
  /// permits each user to read their own row. If not found (or the
  /// query errors), we sign out and treat as unauthenticated so the
  /// user lands on /login and can re-authenticate cleanly.
  Future<void> _resolveAuthState(User user) async {
    bool profileExists = false;
    try {
      final row = await _supabase
          .from('users')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();
      profileExists = row != null;
    } catch (_) {
      profileExists = false;
    }

    if (!profileExists) {
      try { await NotificationService.instance.deleteToken(); } catch (_) { /* best effort */ }
      try { await _supabase.auth.signOut(); } catch (_) { /* ignore */ }
      onRealtimeStop?.call();
      emit(AuthUnauthenticated());
      await _clearLogin();
      return;
    }

    emit(AuthAuthenticated(user));
    await _persistLogin(user.id);
    onRealtimeStart?.call(user);
  }

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
