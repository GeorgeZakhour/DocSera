import 'package:bloc_test/bloc_test.dart';
import 'package:docsera/Business_Logic/Authentication/auth_cubit.dart';
import 'package:docsera/Business_Logic/Authentication/auth_state.dart' as app_state;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}
class MockSharedPreferences extends Mock implements SharedPreferences {}
class MockAuthResponse extends Mock implements AuthResponse {}
class MockUser extends Mock implements User {}
class MockSession extends Mock implements Session {}

void main() {
  late AuthCubit authCubit;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockSharedPreferences mockPrefs;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockPrefs = MockSharedPreferences();

    when(() => mockSupabase.auth).thenReturn(mockAuth);
    
    // Mock initialization flow
    when(() => mockAuth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
    when(() => mockAuth.currentSession).thenReturn(null);
    
    // AuthCubit initialization triggers async storage checks
    // We mock SharedPreferences responses
    when(() => mockPrefs.setBool(any(), any())).thenAnswer((_) async => true);
    when(() => mockPrefs.setString(any(), any())).thenAnswer((_) async => true);
    when(() => mockPrefs.remove(any())).thenAnswer((_) async => true);
    // _clearLogin now iterates getKeys() — return an empty set by default
    // so existing tests keep working. Tests that exercise the cleanup
    // sweep override this stub locally.
    when(() => mockPrefs.getKeys()).thenReturn(<String>{});

    authCubit = AuthCubit(supabase: mockSupabase, prefs: mockPrefs);
  });

  tearDown(() {
    authCubit.close();
  });

  group('AuthCubit', () {
    test('initial state settles to AuthUnauthenticated when no session', () async {
       // Wait for async init to complete
       await Future.delayed(Duration.zero);
       expect(authCubit.state, isA<app_state.AuthUnauthenticated>());
    });

    blocTest<AuthCubit, app_state.AppAuthState>(
      'signInWithEmailAndPassword emits [AuthLoading, AuthError] when fails',
      build: () {
        when(() => mockAuth.signInWithPassword(email: any(named: 'email'), password: any(named: 'password')))
            .thenThrow(const AuthException('Login failed'));
        return authCubit;
      },
      act: (cubit) => cubit.signInWithEmailAndPassword('test@test.com', 'password'),
      expect: () => [
        isA<app_state.AuthLoading>(),
        isA<app_state.AuthError>().having((e) => e.errorMessage, 'errorMessage', 'Login failed'),
      ],
    );

    blocTest<AuthCubit, app_state.AppAuthState>(
      'signInWithEmailAndPassword does NOT emit AuthAuthenticated directly (listener handles it)',
      build: () {
        final mockRes = MockAuthResponse();
        final mockUser = MockUser();
        when(() => mockUser.id).thenReturn('123');
        when(() => mockRes.user).thenReturn(mockUser);
        
        when(() => mockAuth.signInWithPassword(email: any(named: 'email'), password: any(named: 'password')))
            .thenAnswer((_) async => mockRes);
            
        return authCubit;
      },
      act: (cubit) => cubit.signInWithEmailAndPassword('test@test.com', 'password'),
      expect: () => [
        isA<app_state.AuthLoading>(),
        // AuthAuthenticated is emitted by the STREAM listener, NOT the sign in method itself
        // So here we only expect Loading. The stream test is separate.
      ],
    );
     
     blocTest<AuthCubit, app_state.AppAuthState>(
       'signOut emits [AuthUnauthenticated] via stream or method',
       build: () {
          when(() => mockAuth.signOut()).thenAnswer((_) async {});
          return authCubit;
       },
       act: (cubit) => cubit.signOut(),
       verify: (_) {
         verify(() => mockAuth.signOut()).called(1);
       }
     );

    group('_clearLogin (logout cleanup)', () {
      // _clearLogin is private but exercised through _init() when no
      // session is present at startup. The setUp already constructs an
      // AuthCubit with currentSession=null, so each test below builds a
      // fresh cubit after overriding getKeys() with the desired snapshot.

      test('removes PII / session keys while preserving biometric, locale, UI state',
          () async {
        // Tear down the cubit built in setUp so we can re-init with a
        // populated SharedPreferences snapshot.
        await authCubit.close();

        when(() => mockPrefs.getKeys()).thenReturn(<String>{
          // PII — must be removed
          'userEmail',
          'userPhone',
          'userName',
          'userPoints',
          'phoneVerified',
          'isPhoneVerified',
          'isEmailVerified',
          'favoriteDoctors',
          'pending_legal_consents',
          'userId',
          'isLoggedIn',
          // Doctor-session keys (if the embedded doctor screens were used)
          'doctorId',
          'doctorEmail',
          'doctorPhone',
          'doctorName',
          'isDoctorLoggedIn',
          // Preserved — must NOT be removed
          'enableFaceID',
          'biometricType',
          'locale',
          'lastSelectedTab',
          'selectedAppointmentsTab',
          'selectedDocumentsTab',
          'dismissed_banners',
        });

        // Reconstructing the cubit triggers _init() → _clearLogin (no session).
        authCubit = AuthCubit(supabase: mockSupabase, prefs: mockPrefs);
        await Future<void>.delayed(Duration.zero);

        // PII / session keys were wiped
        verify(() => mockPrefs.remove('userEmail')).called(1);
        verify(() => mockPrefs.remove('userPhone')).called(1);
        verify(() => mockPrefs.remove('userName')).called(1);
        verify(() => mockPrefs.remove('userPoints')).called(1);
        verify(() => mockPrefs.remove('phoneVerified')).called(1);
        verify(() => mockPrefs.remove('isPhoneVerified')).called(1);
        verify(() => mockPrefs.remove('isEmailVerified')).called(1);
        verify(() => mockPrefs.remove('favoriteDoctors')).called(1);
        verify(() => mockPrefs.remove('pending_legal_consents')).called(1);
        verify(() => mockPrefs.remove('userId')).called(1);
        verify(() => mockPrefs.remove('doctorId')).called(1);
        verify(() => mockPrefs.remove('doctorEmail')).called(1);
        verify(() => mockPrefs.remove('doctorPhone')).called(1);
        verify(() => mockPrefs.remove('doctorName')).called(1);
        verify(() => mockPrefs.remove('isDoctorLoggedIn')).called(1);
        // 'isLoggedIn' is removed during the sweep, then re-asserted as
        // false explicitly — accept either path.
        verify(() => mockPrefs.remove('isLoggedIn')).called(1);

        // Preserved keys were never removed
        verifyNever(() => mockPrefs.remove('enableFaceID'));
        verifyNever(() => mockPrefs.remove('biometricType'));
        verifyNever(() => mockPrefs.remove('locale'));
        verifyNever(() => mockPrefs.remove('lastSelectedTab'));
        verifyNever(() => mockPrefs.remove('selectedAppointmentsTab'));
        verifyNever(() => mockPrefs.remove('selectedDocumentsTab'));
        verifyNever(() => mockPrefs.remove('dismissed_banners'));

        // isLoggedIn flipped to false explicitly (callers may read this
        // as `false` rather than `null`).
        verify(() => mockPrefs.setBool('isLoggedIn', false)).called(1);
      });

      test('handles empty SharedPreferences without error', () async {
        await authCubit.close();
        when(() => mockPrefs.getKeys()).thenReturn(<String>{});

        authCubit = AuthCubit(supabase: mockSupabase, prefs: mockPrefs);
        await Future<void>.delayed(Duration.zero);

        // Nothing to remove, but the unauthenticated marker is still set.
        verify(() => mockPrefs.setBool('isLoggedIn', false)).called(1);
        verifyNever(() => mockPrefs.remove(any()));
      });

      test('an unknown new pref key is wiped by default (safe-by-default)',
          () async {
        // Regression guard: when a future contributor adds a new pref key
        // and forgets to add it to the preserve list, it must be wiped
        // on logout (not leaked). The keep-list is the explicit allow.
        await authCubit.close();
        when(() => mockPrefs.getKeys()).thenReturn(<String>{
          'someFutureSensitiveKey',
          'anotherNewKey',
        });

        authCubit = AuthCubit(supabase: mockSupabase, prefs: mockPrefs);
        await Future<void>.delayed(Duration.zero);

        verify(() => mockPrefs.remove('someFutureSensitiveKey')).called(1);
        verify(() => mockPrefs.remove('anotherNewKey')).called(1);
      });
    });
  });
}
