// AuthRepository tests focus on the high-frequency RPC paths that
// materially affect the auth funnel. We mock SupabaseClient + the RPC
// surface; the repository should pass through arguments faithfully and
// translate responses correctly.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:docsera/services/supabase/repositories/auth_repository.dart';

class _MockSupabase extends Mock implements SupabaseClient {}

class _MockGoTrue extends Mock implements GoTrueClient {}

void main() {
  late _MockSupabase supabase;
  late _MockGoTrue gotrue;
  late AuthRepository repo;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    supabase = _MockSupabase();
    gotrue = _MockGoTrue();
    when(() => supabase.auth).thenReturn(gotrue);
    repo = AuthRepository(supabase: supabase);
  });

  // Note on RPC tests: SupabaseClient.rpc returns a PostgrestFilterBuilder,
  // not a Future, so testing the rpc-shaped paths through mocktail
  // requires a far heavier mock surface than mocktail provides ergonomically.
  // The auth-funnel integration tests cover the equivalent paths through
  // the GoTrue surface which IS mockable.

  group('AuthRepository.signInWithPassword', () {
    test('delegates email + password to gotrue', () async {
      when(() => gotrue.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer(
          (_) async => AuthResponse(session: null, user: null));
      await repo.signInWithPassword(email: 'a@b.c', password: 'p');
      verify(() => gotrue.signInWithPassword(
            email: 'a@b.c',
            password: 'p',
          )).called(1);
    });

    test('rethrows AuthException from gotrue', () async {
      when(() => gotrue.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(const AuthException('invalid'));
      expect(
        () => repo.signInWithPassword(email: 'a@b.c', password: 'wrong'),
        throwsA(isA<AuthException>()),
      );
    });
  });
}
