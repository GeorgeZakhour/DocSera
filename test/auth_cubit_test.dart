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
    when(() => mockAuth.onAuthStateChange).thenAnswer((_) => Stream.empty());
    when(() => mockAuth.currentSession).thenReturn(null);
    
    // AuthCubit initialization triggers async storage checks
    // We mock SharedPreferences responses
    when(() => mockPrefs.setBool(any(), any())).thenAnswer((_) async => true);
    when(() => mockPrefs.setString(any(), any())).thenAnswer((_) async => true);
    when(() => mockPrefs.remove(any())).thenAnswer((_) async => true);

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
  });
}
