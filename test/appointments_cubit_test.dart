import 'package:bloc_test/bloc_test.dart';
import 'package:docsera/Business_Logic/Appointments_page/appointments_cubit.dart';
import 'package:docsera/Business_Logic/Appointments_page/appointments_state.dart';
import 'package:docsera/services/supabase/user/supabase_user_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSupabaseUserService extends Mock implements SupabaseUserService {}
class MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  late AppointmentsCubit cubit;
  late MockSupabaseUserService mockUserService;
  late MockSharedPreferences mockPrefs;

  setUp(() {
    mockUserService = MockSupabaseUserService();
    mockPrefs = MockSharedPreferences();
    cubit = AppointmentsCubit(mockUserService, mockPrefs);
  });

  tearDown(() {
    cubit.close();
  });

  final mockUpcoming = [{'id': '1', 'timestamp': DateTime.now().add(const Duration(days: 1)).toIso8601String()}];
  final mockPast = [{'id': '2', 'timestamp': DateTime.now().subtract(const Duration(days: 1)).toIso8601String()}];
  final mockAppointments = {'upcoming': mockUpcoming, 'past': mockPast};

  group('AppointmentsCubit', () {
    test('initial state is AppointmentsLoading', () {
      expect(cubit.state, isA<AppointmentsLoading>());
    });

    blocTest<AppointmentsCubit, AppointmentsState>(
      'loadAppointments emits [AppointmentsLoading, AppointmentsLoaded] when successful',
      build: () {
        when(() => mockPrefs.getInt('lastSelectedTab')).thenReturn(0);
        when(() => mockPrefs.getString('upcomingAppointments')).thenReturn(null);
        when(() => mockPrefs.getString('pastAppointments')).thenReturn(null);
        when(() => mockUserService.getUserAppointments('user-1')).thenAnswer((_) async => mockAppointments);
        when(() => mockUserService.saveCachedData(any(), any())).thenAnswer((_) async {});
        when(() => mockUserService.listenToUserAppointments('user-1')).thenAnswer((_) => Stream.empty());

        return cubit;
      },
      act: (cubit) => cubit.loadAppointments(explicitUserId: 'user-1', useCache: false),
      expect: () => [
        isA<AppointmentsLoading>(),
        isA<AppointmentsLoaded>()
            .having((s) => s.upcomingAppointments.length, 'upcoming length', 1)
            .having((s) => s.pastAppointments.length, 'past length', 1),
      ],
    );

    blocTest<AppointmentsCubit, AppointmentsState>(
      'loadAppointments emits [AppointmentsError] when service throws',
      build: () {
        when(() => mockPrefs.getInt('lastSelectedTab')).thenReturn(0);
        when(() => mockUserService.getUserAppointments('user-1')).thenThrow(Exception('Backend failed'));

        return cubit;
      },
      act: (cubit) => cubit.loadAppointments(explicitUserId: 'user-1', useCache: false),
      expect: () => [
        isA<AppointmentsLoading>(),
        isA<AppointmentsError>().having((e) => e.message, 'message', contains('Backend failed')),
      ],
    );

     blocTest<AppointmentsCubit, AppointmentsState>(
       'loadAppointments emits [NotLoggedIn] when no user id provided',
       build: () => cubit,
       act: (cubit) => cubit.loadAppointments(),
       expect: () => [
         isA<AppointmentsLoading>(),
         isA<NotLoggedIn>(),
       ],
     );
  });
}
