import 'package:bloc_test/bloc_test.dart';
import 'package:docsera/Business_Logic/Account_page/user_cubit.dart';
import 'package:docsera/Business_Logic/Account_page/user_state.dart';
import 'package:docsera/services/supabase/user/supabase_user_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mocks
class MockSupabaseUserService extends Mock implements SupabaseUserService {}
class MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  late UserCubit userCubit;
  late MockSupabaseUserService mockUserService;
  late MockSharedPreferences mockPrefs;

  setUp(() {
    mockUserService = MockSupabaseUserService();
    mockPrefs = MockSharedPreferences();
    userCubit = UserCubit(mockUserService, mockPrefs);
  });

  tearDown(() {
    userCubit.close();
  });

  group('UserCubit', () {
    const userId = 'user-123';
    
    // Sample response matching Supabase user table structure
    final mockUserMap = {
      'is_active': true,
      'first_name': 'George',
      'last_name': 'Zakhour',
      'email': 'george@example.com',
      'phone_number': '0912345678',
      'phone_verified': true,
      'email_verified': true,
      'two_factor_auth_enabled': false,
      'points': 100,
      'gender': 'male',
      'date_of_birth': '1990-01-01',
      'address': {'city': 'Damascus'}
    };

    test('initial state is UserLoading', () {
      expect(userCubit.state, isA<UserLoading>());
    });

    blocTest<UserCubit, UserState>(
      'emits [UserLoaded] when loadUserData is called successfully',
      build: () {
        // Setup SharedPreferences Stubs to prevent NPE
        when(() => mockPrefs.getString(any())).thenReturn(null);
        when(() => mockPrefs.getBool(any())).thenReturn(null);
        when(() => mockPrefs.getInt(any())).thenReturn(null);
        when(() => mockPrefs.setString(any(), any())).thenAnswer((_) async => true);
        when(() => mockPrefs.setBool(any(), any())).thenAnswer((_) async => true);
        when(() => mockPrefs.setInt(any(), any())).thenAnswer((_) async => true);

        // Setup Service Response
        when(() => mockUserService.getUserData(userId))
            .thenAnswer((_) async => mockUserMap);
        
        return userCubit;
      },
      act: (cubit) => cubit.loadUserData(explicitUserId: userId, useCache: false),
      expect: () => [
        isA<UserLoaded>()
            .having((state) => state.userId, 'userId', userId)
            .having((state) => state.userName, 'userName', 'George Zakhour')
            .having((state) => state.userEmail, 'userEmail', 'george@example.com')
            .having((state) => state.userPoints, 'userPoints', 100)
      ],
    );
     
    blocTest<UserCubit, UserState>(
      'emits [UserError] when getUserData returns null',
      build: () {
        when(() => mockUserService.getUserData(userId))
            .thenAnswer((_) async => null);
        return userCubit;
      },
      act: (cubit) => cubit.loadUserData(explicitUserId: userId, useCache: false),
      expect: () => [
        isA<UserError>().having((state) => state.message, 'message', 'User data not found')
      ],
    );

    blocTest<UserCubit, UserState>(
      'emits [UserError] when service throws exception',
      build: () {
         when(() => mockUserService.getUserData(userId))
            .thenThrow(Exception('Network error'));
         return userCubit;
      },
      act: (cubit) => cubit.loadUserData(explicitUserId: userId, useCache: false),
      expect: () => [
        isA<UserError>().having((state) => state.message, 'message', contains('Network error'))
      ],
    );
  });
}
