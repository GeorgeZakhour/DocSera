// test/health_profile_wizard_cubit_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:docsera/Business_Logic/Health_page/wizard/health_profile_wizard_cubit.dart';
import 'package:docsera/Business_Logic/Health_page/wizard/health_profile_wizard_state.dart';
import 'package:docsera/services/supabase/repositories/health_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements HealthProfileRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const WizardAnswers());
  });

  group('HealthProfileWizardCubit', () {
    late _MockRepo repo;

    setUp(() {
      repo = _MockRepo();
      when(() => repo.fetchOwnProfile(any())).thenAnswer((_) async => null);
      when(() => repo.upsertVitalsLifestyle(
            heightCm: any(named: 'heightCm'),
            weightKg: any(named: 'weightKg'),
            sportFrequency: any(named: 'sportFrequency'),
            smokingStatus: any(named: 'smokingStatus'),
            alcoholFrequency: any(named: 'alcoholFrequency'),
          )).thenAnswer((_) async {});
    });

    HealthProfileWizardCubit build() =>
        HealthProfileWizardCubit(repo: repo, userId: 'u1');

    blocTest<HealthProfileWizardCubit, HealthProfileWizardState>(
      'init starts at step 0 with empty answers when no row exists',
      build: build,
      act: (c) => c.init(),
      expect: () => [
        isA<WizardActive>()
            .having((s) => s.stepIndex, 'stepIndex', 0)
            .having((s) => s.answers, 'answers', const WizardAnswers()),
      ],
    );

    blocTest<HealthProfileWizardCubit, HealthProfileWizardState>(
      'init hydrates answers from existing row',
      build: () {
        when(() => repo.fetchOwnProfile(any())).thenAnswer((_) async => {
              'height_cm': 178,
              'weight_kg': 75,
              'sport_frequency': '1_2',
              'smoking_status': 'never',
              'alcohol_frequency': 'never',
            });
        return build();
      },
      act: (c) => c.init(),
      expect: () => [
        isA<WizardActive>().having(
          (s) => s.answers,
          'answers',
          const WizardAnswers(
            heightCm: 178,
            weightKg: 75,
            sportFrequency: '1_2',
            smokingStatus: 'never',
            alcoholFrequency: 'never',
          ),
        ),
      ],
    );

    blocTest<HealthProfileWizardCubit, HealthProfileWizardState>(
      'setHeight then next moves to step 1 and persists',
      build: build,
      seed: () => const WizardActive(stepIndex: 0, answers: WizardAnswers()),
      act: (c) async {
        c.setHeight(178);
        await c.next();
      },
      verify: (_) {
        verify(() => repo.upsertVitalsLifestyle(heightCm: 178)).called(1);
      },
      expect: () => [
        isA<WizardActive>().having((s) => s.answers.heightCm, 'heightCm', 178),
        isA<WizardActive>().having((s) => s.stepIndex, 'stepIndex', 1),
      ],
    );

    blocTest<HealthProfileWizardCubit, HealthProfileWizardState>(
      'finalising calls completeHealthProfile and emits Completed',
      build: () {
        when(() => repo.completeHealthProfile()).thenAnswer((_) async =>
            CompleteHealthProfileResult(
              alreadyAwarded: false,
              newBalance: 35,
              completedAt: DateTime.now(),
            ));
        return build();
      },
      seed: () => const WizardActive(
          stepIndex: kWizardTotalInputSteps - 1, answers: WizardAnswers()),
      act: (c) => c.next(),
      expect: () => [
        isA<WizardActive>()
            .having((s) => s.submittingFinal, 'submittingFinal', true),
        isA<WizardCompleted>()
            .having((s) => s.newBalance, 'newBalance', 35)
            .having((s) => s.alreadyAwarded, 'alreadyAwarded', false),
      ],
    );

    blocTest<HealthProfileWizardCubit, HealthProfileWizardState>(
      'back decrements stepIndex but never goes below 0',
      build: build,
      seed: () => const WizardActive(stepIndex: 1, answers: WizardAnswers()),
      act: (c) {
        c.back();
        c.back(); // second call at stepIndex=0 should be a no-op
      },
      expect: () => [
        isA<WizardActive>().having((s) => s.stepIndex, 'stepIndex', 0),
      ],
    );

    blocTest<HealthProfileWizardCubit, HealthProfileWizardState>(
      'skip behaves identically to next()',
      build: build,
      seed: () => const WizardActive(stepIndex: 2, answers: WizardAnswers()),
      act: (c) => c.skip(),
      expect: () => [
        isA<WizardActive>().having((s) => s.stepIndex, 'stepIndex', 3),
      ],
    );

    blocTest<HealthProfileWizardCubit, HealthProfileWizardState>(
      'upsert failure during next() emits WizardError',
      build: () {
        when(() => repo.upsertVitalsLifestyle(
              heightCm: any(named: 'heightCm'),
              weightKg: any(named: 'weightKg'),
              sportFrequency: any(named: 'sportFrequency'),
              smokingStatus: any(named: 'smokingStatus'),
              alcoholFrequency: any(named: 'alcoholFrequency'),
            )).thenThrow(Exception('boom'));
        return build();
      },
      seed: () => const WizardActive(stepIndex: 0, answers: WizardAnswers()),
      act: (c) => c.next(),
      expect: () => [
        isA<WizardError>().having((s) => s.message, 'message', contains('boom')),
      ],
    );
  });
}
