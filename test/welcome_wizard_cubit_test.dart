import 'package:bloc_test/bloc_test.dart';
import 'package:docsera/Business_Logic/Onboarding/welcome_wizard/welcome_wizard_cubit.dart';
import 'package:docsera/Business_Logic/Onboarding/welcome_wizard/welcome_wizard_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WelcomeWizardCubit', () {
    blocTest<WelcomeWizardCubit, WelcomeWizardState>(
      'starts at page 0 in firstTime mode',
      build: () => WelcomeWizardCubit(entryMode: WizardEntryMode.firstTime, totalPages: 18),
      verify: (c) {
        expect(c.state.currentPage, 0);
        expect(c.state.entryMode, WizardEntryMode.firstTime);
        expect(c.state.completed, false);
      },
    );

    blocTest<WelcomeWizardCubit, WelcomeWizardState>(
      'next() advances page index',
      build: () => WelcomeWizardCubit(entryMode: WizardEntryMode.firstTime, totalPages: 18),
      act: (c) {
        c.next();
        c.next();
      },
      expect: () => [
        isA<WelcomeWizardState>().having((s) => s.currentPage, 'currentPage', 1),
        isA<WelcomeWizardState>().having((s) => s.currentPage, 'currentPage', 2),
      ],
    );

    blocTest<WelcomeWizardCubit, WelcomeWizardState>(
      'next() on last page emits completed=true',
      build: () => WelcomeWizardCubit(entryMode: WizardEntryMode.firstTime, totalPages: 3),
      act: (c) {
        c.jumpTo(2);
        c.next();
      },
      expect: () => [
        isA<WelcomeWizardState>().having((s) => s.currentPage, 'currentPage', 2),
        isA<WelcomeWizardState>().having((s) => s.completed, 'completed', true),
      ],
    );

    blocTest<WelcomeWizardCubit, WelcomeWizardState>(
      'previous() decrements but not below 0',
      build: () => WelcomeWizardCubit(entryMode: WizardEntryMode.firstTime, totalPages: 18),
      act: (c) {
        c.jumpTo(1);
        c.previous();
        c.previous();
      },
      expect: () => [
        isA<WelcomeWizardState>().having((s) => s.currentPage, 'currentPage', 1),
        isA<WelcomeWizardState>().having((s) => s.currentPage, 'currentPage', 0),
        // second previous() does not emit (already at 0)
      ],
    );

    blocTest<WelcomeWizardCubit, WelcomeWizardState>(
      'jumpTo(n) sets currentPage to n',
      build: () => WelcomeWizardCubit(entryMode: WizardEntryMode.firstTime, totalPages: 18),
      act: (c) => c.jumpTo(7),
      expect: () => [
        isA<WelcomeWizardState>().having((s) => s.currentPage, 'currentPage', 7),
      ],
    );

    blocTest<WelcomeWizardCubit, WelcomeWizardState>(
      'skip() in firstTime mode persists the completion flag',
      build: () => WelcomeWizardCubit(entryMode: WizardEntryMode.firstTime, totalPages: 18),
      act: (c) => c.skip(),
      expect: () => [
        isA<WelcomeWizardState>().having((s) => s.completed, 'completed', true),
      ],
      verify: (_) async {
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('welcome_wizard_completed_v1'), true);
      },
    );

    blocTest<WelcomeWizardCubit, WelcomeWizardState>(
      'skip() in replay mode does NOT persist the completion flag',
      build: () => WelcomeWizardCubit(entryMode: WizardEntryMode.replay, totalPages: 18),
      act: (c) => c.skip(),
      expect: () => [
        isA<WelcomeWizardState>().having((s) => s.completed, 'completed', true),
      ],
      verify: (_) async {
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('welcome_wizard_completed_v1'), null);
      },
    );

    blocTest<WelcomeWizardCubit, WelcomeWizardState>(
      'complete() in firstTime mode persists the flag',
      build: () => WelcomeWizardCubit(entryMode: WizardEntryMode.firstTime, totalPages: 3),
      act: (c) {
        c.jumpTo(2);
        c.next();
      },
      verify: (_) async {
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('welcome_wizard_completed_v1'), true);
      },
    );

    blocTest<WelcomeWizardCubit, WelcomeWizardState>(
      'complete() in replay mode does NOT persist',
      build: () => WelcomeWizardCubit(entryMode: WizardEntryMode.replay, totalPages: 3),
      act: (c) {
        c.jumpTo(2);
        c.next();
      },
      verify: (_) async {
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('welcome_wizard_completed_v1'), null);
      },
    );
  });

  group('hasCompletedWizard()', () {
    test('returns false when flag is missing', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await WelcomeWizardCubit.hasCompletedWizard(), false);
    });

    test('returns true when flag is set', () async {
      SharedPreferences.setMockInitialValues({
        'welcome_wizard_completed_v1': true,
      });
      expect(await WelcomeWizardCubit.hasCompletedWizard(), true);
    });
  });

  group('migrateExistingUser()', () {
    test('sets the flag if missing', () async {
      SharedPreferences.setMockInitialValues({});
      await WelcomeWizardCubit.migrateExistingUser();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('welcome_wizard_completed_v1'), true);
    });

    test('does not overwrite the flag if already set', () async {
      SharedPreferences.setMockInitialValues({
        'welcome_wizard_completed_v1': false,
      });
      await WelcomeWizardCubit.migrateExistingUser();
      final prefs = await SharedPreferences.getInstance();
      // existing value preserved
      expect(prefs.getBool('welcome_wizard_completed_v1'), false);
    });
  });
}
