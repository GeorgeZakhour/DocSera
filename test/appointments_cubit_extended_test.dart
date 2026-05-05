// Extended AppointmentsCubit tests covering tab persistence, logout,
// stream-driven re-emission, and caching behavior. Complements the
// existing test/appointments_cubit_test.dart which covers the basic
// load path.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:docsera/Business_Logic/Appointments_page/appointments_cubit.dart';
import 'package:docsera/Business_Logic/Appointments_page/appointments_state.dart';
import 'package:docsera/services/supabase/user/supabase_user_service.dart';

import '_helpers/tz_init.dart';

class _MockUserService extends Mock implements SupabaseUserService {}

class _MockPrefs extends Mock implements SharedPreferences {}

void main() {
  setUpAll(initTzForTests);

  late AppointmentsCubit cubit;
  late _MockUserService userService;
  late _MockPrefs prefs;

  setUp(() {
    userService = _MockUserService();
    prefs = _MockPrefs();
    when(() => prefs.getInt('lastSelectedTab')).thenReturn(0);
    when(() => prefs.getString(any())).thenReturn(null);
    cubit = AppointmentsCubit(userService, prefs);
  });

  tearDown(() => cubit.close());

  group('AppointmentsCubit — loadAppointments edge cases', () {
    blocTest<AppointmentsCubit, AppointmentsState>(
      'no user (no context, no explicitUserId) emits NotLoggedIn',
      build: () => cubit,
      act: (c) => c.loadAppointments(),
      expect: () => [isA<NotLoggedIn>()],
    );

    blocTest<AppointmentsCubit, AppointmentsState>(
      'getUserAppointments throws → AppointmentsError',
      build: () {
        when(() => userService.getUserAppointments('user-1'))
            .thenThrow(Exception('db down'));
        return cubit;
      },
      act: (c) => c.loadAppointments(explicitUserId: 'user-1', useCache: false),
      expect: () => [
        isA<AppointmentsLoading>(),
        isA<AppointmentsError>(),
      ],
    );

    blocTest<AppointmentsCubit, AppointmentsState>(
      'second loadAppointments with same user is a no-op (cache hit)',
      build: () {
        when(() => userService.getUserAppointments('user-1'))
            .thenAnswer((_) async => {'upcoming': [], 'past': []});
        when(() => userService.saveCachedData(any(), any()))
            .thenAnswer((_) async {});
        when(() => userService.listenToUserAppointments('user-1'))
            .thenAnswer((_) => const Stream.empty());
        return cubit;
      },
      act: (c) async {
        await c.loadAppointments(explicitUserId: 'user-1', useCache: false);
        await c.loadAppointments(explicitUserId: 'user-1', useCache: false);
      },
      // Second call short-circuits, so we get only one Loading→Loaded cycle.
      verify: (_) {
        verify(() => userService.getUserAppointments('user-1')).called(1);
      },
    );

    blocTest<AppointmentsCubit, AppointmentsState>(
      'forceReload bypasses the cache check and refetches',
      build: () {
        when(() => userService.getUserAppointments('user-1'))
            .thenAnswer((_) async => {'upcoming': [], 'past': []});
        when(() => userService.saveCachedData(any(), any()))
            .thenAnswer((_) async {});
        when(() => userService.listenToUserAppointments('user-1'))
            .thenAnswer((_) => const Stream.empty());
        return cubit;
      },
      act: (c) async {
        await c.loadAppointments(explicitUserId: 'user-1', useCache: false);
        await c.loadAppointments(
            explicitUserId: 'user-1', useCache: false, forceReload: true);
      },
      verify: (_) {
        verify(() => userService.getUserAppointments('user-1')).called(2);
      },
    );
  });

  group('AppointmentsCubit — updateSelectedTab', () {
    blocTest<AppointmentsCubit, AppointmentsState>(
      'persists the tab and re-emits Loaded state when one exists',
      build: () {
        when(() => prefs.setInt('lastSelectedTab', any()))
            .thenAnswer((_) async => true);
        cubit.emit(const AppointmentsLoaded(
          upcomingAppointments: [],
          pastAppointments: [],
          selectedTab: 0,
        ));
        return cubit;
      },
      act: (c) => c.updateSelectedTab(1),
      verify: (c) {
        verify(() => prefs.setInt('lastSelectedTab', 1)).called(1);
        expect((c.state as AppointmentsLoaded).selectedTab, 1);
      },
    );

    blocTest<AppointmentsCubit, AppointmentsState>(
      'no Loaded state → tab is persisted but no emission',
      build: () {
        when(() => prefs.setInt('lastSelectedTab', any()))
            .thenAnswer((_) async => true);
        return cubit;
      },
      act: (c) => c.updateSelectedTab(2),
      expect: () => const <AppointmentsState>[],
      verify: (_) {
        verify(() => prefs.setInt('lastSelectedTab', 2)).called(1);
      },
    );
  });

  group('AppointmentsCubit — logout', () {
    blocTest<AppointmentsCubit, AppointmentsState>(
      'clears prefs, cancels stream, emits NotLoggedIn',
      build: () {
        when(() => prefs.clear()).thenAnswer((_) async => true);
        return cubit;
      },
      act: (c) => c.logout(),
      expect: () => [isA<NotLoggedIn>()],
      verify: (_) {
        verify(() => prefs.clear()).called(1);
      },
    );
  });

  group('AppointmentsCubit — setAppointmentsFromStream', () {
    blocTest<AppointmentsCubit, AppointmentsState>(
      'emits AppointmentsLoaded with given upcoming/past lists',
      build: () => cubit,
      act: (c) => c.setAppointmentsFromStream(
        upcoming: const [{'id': 'a'}],
        past: const [{'id': 'b'}],
      ),
      expect: () => [
        isA<AppointmentsLoaded>()
            .having((s) => s.upcomingAppointments.length, 'upcoming', 1)
            .having((s) => s.pastAppointments.length, 'past', 1),
      ],
    );
  });
}
