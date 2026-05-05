// Booking funnel integration test — verifies the AppointmentDetails
// state-machine that drives the booking flow, plus the AppointmentsCubit
// path that surfaces newly-booked appointments to the UI.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:docsera/Business_Logic/Appointments_page/appointments_cubit.dart';
import 'package:docsera/Business_Logic/Appointments_page/appointments_state.dart';
import 'package:docsera/services/supabase/user/supabase_user_service.dart';

import '../_helpers/fixtures.dart';
import '../_helpers/tz_init.dart';

class _MockUserService extends Mock implements SupabaseUserService {}

void main() {
  setUpAll(initTzForTests);

  late AppointmentsCubit cubit;
  late _MockUserService userService;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    userService = _MockUserService();
    cubit = AppointmentsCubit(userService, prefs);
  });

  tearDown(() => cubit.close());

  group('BookingFunnel — appointment details building', () {
    test('starting from a doctor selection populates doctor + clinic', () {
      final details = Fixtures.appointmentDetails(
        doctorId: 'd-7',
        doctorName: 'Dr. House',
        specialty: 'Cardiology',
        clinicName: 'Heart Clinic',
      );
      expect(details.doctorId, 'd-7');
      expect(details.doctorName, 'Dr. House');
      expect(details.clinicName, 'Heart Clinic');
    });

    test('selecting a reason fills the reason field', () {
      final base = Fixtures.appointmentDetails();
      final updated = base.copyWith(reason: 'Annual Check-up');
      expect(updated.reason, 'Annual Check-up');
    });

    test('selecting a relative flips isRelative and updates patient identity',
        () {
      final base = Fixtures.appointmentDetails();
      final forRelative = base.copyWith(
        isRelative: true,
        patientId: 'rel-1',
        patientName: 'Mom',
        patientAge: 60,
      );
      expect(forRelative.isRelative, true);
      expect(forRelative.patientId, 'rel-1');
      expect(forRelative.patientName, 'Mom');
      expect(forRelative.patientAge, 60);
    });

    test('clinicAddress and location can be updated independently', () {
      final base = Fixtures.appointmentDetails();
      final updated = base.copyWith(
        clinicAddress: {'street': '99 New', 'city': 'Aleppo'},
        location: {'lat': 36.20, 'lng': 37.13},
      );
      expect(updated.clinicAddress['city'], 'Aleppo');
      expect(updated.location?['lat'], 36.20);
    });
  });

  group('BookingFunnel — appointments list reflects new bookings', () {
    blocTest<AppointmentsCubit, AppointmentsState>(
      'after booking, refetch surfaces the new appointment in upcoming',
      build: () {
        // First call: empty list. Second call (after refresh): includes
        // the newly-booked appointment.
        final calls = <List<Map<String, dynamic>>>[
          [],
          [
            {
              'id': 'apt-new',
              'timestamp': DateTime.now()
                  .add(const Duration(days: 3))
                  .toIso8601String(),
              'doctor_name': 'Dr. House',
            },
          ],
        ];
        var i = 0;
        when(() => userService.getUserAppointments('user-1'))
            .thenAnswer((_) async {
          final upcoming = calls[i++];
          return {'upcoming': upcoming, 'past': const []};
        });
        when(() => userService.saveCachedData(any(), any()))
            .thenAnswer((_) async {});
        when(() => userService.listenToUserAppointments('user-1'))
            .thenAnswer((_) => const Stream.empty());
        return cubit;
      },
      act: (c) async {
        await c.loadAppointments(explicitUserId: 'user-1', useCache: false);
        // Simulating: book happened on the server. Now re-fetch.
        await c.loadAppointments(
          explicitUserId: 'user-1',
          useCache: false,
          forceReload: true,
        );
      },
      verify: (c) {
        final loaded = c.state as AppointmentsLoaded;
        expect(loaded.upcomingAppointments.length, 1);
        expect(loaded.upcomingAppointments.first['id'], 'apt-new');
      },
    );
  });
}
