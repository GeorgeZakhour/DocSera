import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_state.dart'; // يحتوي AppAuthState

class AuthCubit extends Cubit<AppAuthState> {
  final SupabaseClient _supabase = Supabase.instance.client;
  late final StreamSubscription _authSubscription;
  late SharedPreferences _prefs;

  AuthCubit() : super(AuthInitial()) {
    _init();
  }

  Future<void> _init() async {
    emit(AuthLoading());
    _prefs = await SharedPreferences.getInstance();

    _authSubscription = _supabase.auth.onAuthStateChange.listen(
          (event) async {
        final session = event.session;
        final user = session?.user;

        if (user == null) {
          emit(AuthUnauthenticated());
          await _prefs.setBool('isLoggedIn', false);
          await _prefs.remove('userId');
        } else {
          emit(AuthAuthenticated(user));
          await _prefs.setBool('isLoggedIn', true);
          await _prefs.setString('userId', user.id);
        }
      },
      onError: (error) {
        emit(AuthError("Auth State Stream Error: $error"));
      },
    );


  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      emit(AuthLoading());
      final res = await _supabase.auth.signInWithPassword(email: email, password: password);
      if (res.user == null) {
        emit(AuthError("Login failed: No user returned."));
      }
    } on AuthException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(AuthError("Unexpected signIn error: $e"));
    }
  }

  Future<void> signUpWithEmailAndPassword(String email, String password) async {
    try {
      emit(AuthLoading());
      final res = await _supabase.auth.signUp(email: email, password: password);
      if (res.user == null) {
        emit(AuthError("Sign up failed: No user returned."));
      }
    } on AuthException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(AuthError("Unexpected signUp error: $e"));
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      emit(AuthError("Sign out error: $e"));
    }
  }

  @override
  Future<void> close() {
    _authSubscription.cancel();
    return super.close();
  }
}
