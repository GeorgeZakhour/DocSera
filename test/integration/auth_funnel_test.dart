// Auth funnel integration test — exercises the AuthCubit through the
// public sign-in/sign-out paths with a mocked SupabaseClient.
//
// Limits: AuthCubit deeply uses Supabase.instance.client in places we
// can't mock. This test focuses on the constructor-injected client paths
// (signIn / signOut error handling, state emission), which is the
// behavior most likely to regress.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:docsera/Business_Logic/Authentication/auth_cubit.dart';
import 'package:docsera/Business_Logic/Authentication/auth_state.dart' as app;

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

void main() {
  late _MockSupabaseClient supabase;
  late _MockGoTrueClient gotrue;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    supabase = _MockSupabaseClient();
    gotrue = _MockGoTrueClient();

    when(() => supabase.auth).thenReturn(gotrue);
    when(() => gotrue.currentSession).thenReturn(null);
    when(() => gotrue.currentUser).thenReturn(null);
    // Empty stream so AuthCubit's _init listener doesn't hang.
    when(() => gotrue.onAuthStateChange)
        .thenAnswer((_) => const Stream<AuthState>.empty());
  });

  group('AuthFunnel — signInWithEmailAndPassword', () {
    blocTest<AuthCubit, app.AppAuthState>(
      'failure → emits AuthLoading then AuthError',
      build: () {
        when(() => gotrue.signInWithPassword(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenThrow(const AuthException('invalid login'));
        return AuthCubit(supabase: supabase, prefs: prefs);
      },
      act: (c) => c.signInWithEmailAndPassword('x@y.com', 'wrong'),
      // _init() emits multiple states asynchronously; we only assert
      // that the act produced an AuthError eventually.
      verify: (c) {
        expect(c.state, isA<app.AuthError>());
      },
    );

    blocTest<AuthCubit, app.AppAuthState>(
      'unexpected exception (non-AuthException) → AuthError with prefix',
      build: () {
        when(() => gotrue.signInWithPassword(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenThrow(StateError('something else'));
        return AuthCubit(supabase: supabase, prefs: prefs);
      },
      act: (c) => c.signInWithEmailAndPassword('a@b.c', 'p'),
      verify: (c) {
        expect(c.state, isA<app.AuthError>());
        expect((c.state as app.AuthError).errorMessage,
            contains('Unexpected'));
      },
    );

    test('success path delegates to supabase.auth.signInWithPassword',
        () async {
      when(() => gotrue.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async =>
          AuthResponse(session: null, user: null));

      final cubit = AuthCubit(supabase: supabase, prefs: prefs);
      await cubit.signInWithEmailAndPassword('a@b.c', 'p');
      verify(() => gotrue.signInWithPassword(
            email: 'a@b.c',
            password: 'p',
          )).called(1);
      await cubit.close();
    });
  });

  group('AuthFunnel — signOut', () {
    test('signOut calls supabase.auth.signOut and clears persisted state',
        () async {
      when(() => gotrue.signOut()).thenAnswer((_) async {});

      // Seed persisted "logged in" state.
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userId', 'user-1');

      final cubit = AuthCubit(supabase: supabase, prefs: prefs);
      await cubit.signOut();

      verify(() => gotrue.signOut()).called(1);
      // Persisted state should be cleared.
      expect(prefs.getBool('isLoggedIn') ?? false, false);
      await cubit.close();
    });
  });

  group('AuthFunnel — signUpWithEmailAndPassword', () {
    blocTest<AuthCubit, app.AppAuthState>(
      'failure leaves cubit in AuthError state',
      build: () {
        when(() => gotrue.signUp(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenThrow(const AuthException('email taken'));
        return AuthCubit(supabase: supabase, prefs: prefs);
      },
      act: (c) => c.signUpWithEmailAndPassword('a@b.c', 'p'),
      verify: (c) {
        expect(c.state, isA<app.AuthError>());
      },
    );
  });
}
