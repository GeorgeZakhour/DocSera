// Extended UserCubit tests covering logout (which preserves biometric
// settings while clearing other prefs).

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:docsera/Business_Logic/Account_page/user_cubit.dart';
import 'package:docsera/Business_Logic/Account_page/user_state.dart';
import 'package:docsera/services/supabase/user/supabase_user_service.dart';

class _MockUserService extends Mock implements SupabaseUserService {}

void main() {
  late SharedPreferences prefs;
  late _MockUserService userService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'enableFaceID': true,
      'biometricType': 'fingerprint',
      'someOtherKey': 'should-be-cleared',
      'userName': 'John',
    });
    prefs = await SharedPreferences.getInstance();
    userService = _MockUserService();
  });

  group('UserCubit.logout', () {
    blocTest<UserCubit, UserState>(
      'preserves biometric settings while clearing other prefs',
      build: () => UserCubit(userService, prefs),
      act: (c) => c.logout(),
      verify: (_) {
        // Biometric settings preserved.
        expect(prefs.getBool('enableFaceID'), true);
        expect(prefs.getString('biometricType'), 'fingerprint');
        // Other keys cleared.
        expect(prefs.getString('someOtherKey'), isNull);
        expect(prefs.getString('userName'), isNull);
      },
      expect: () => [isA<NotLogged>()],
    );

    blocTest<UserCubit, UserState>(
      'when no biometric was set, logout still emits NotLogged cleanly',
      build: () {
        SharedPreferences.setMockInitialValues({});
        return UserCubit(userService, prefs);
      },
      act: (c) => c.logout(),
      expect: () => [isA<NotLogged>()],
    );

    blocTest<UserCubit, UserState>(
      'logout clears the userId pref',
      build: () => UserCubit(userService, prefs),
      act: (c) async {
        await prefs.setString('userId', 'user-1');
        await c.logout();
      },
      verify: (_) {
        expect(prefs.getString('userId'), isNull);
      },
    );
  });

  group('UserCubit — initial state', () {
    test('starts in UserLoading', () {
      final c = UserCubit(userService, prefs);
      expect(c.state, isA<UserLoading>());
      c.close();
    });
  });
}
