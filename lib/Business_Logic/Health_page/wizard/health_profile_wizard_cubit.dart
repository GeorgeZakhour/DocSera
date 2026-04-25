// lib/Business_Logic/Health_page/wizard/health_profile_wizard_cubit.dart
import 'package:bloc/bloc.dart';
import 'package:docsera/Business_Logic/Health_page/wizard/health_profile_wizard_state.dart';
import 'package:docsera/services/supabase/repositories/health_profile_repository.dart';

class HealthProfileWizardCubit extends Cubit<HealthProfileWizardState> {
  final HealthProfileRepository _repo;
  final String _userId;

  HealthProfileWizardCubit({
    required HealthProfileRepository repo,
    required String userId,
  })  : _repo = repo,
        _userId = userId,
        super(const WizardLoading());

  /// Hydrate from an existing patient_health_profile row (if any) and emit
  /// WizardActive at step 0.
  Future<void> init() async {
    try {
      final existing = await _repo.fetchOwnProfile(_userId);
      final answers = WizardAnswers(
        heightCm: existing?['height_cm'] as num?,
        weightKg: existing?['weight_kg'] as num?,
        sportFrequency: existing?['sport_frequency'] as String?,
        smokingStatus: existing?['smoking_status'] as String?,
        alcoholFrequency: existing?['alcohol_frequency'] as String?,
      );
      emit(WizardActive(stepIndex: 0, answers: answers));
    } catch (e) {
      emit(WizardError(e.toString()));
    }
  }

  WizardActive? get _active =>
      state is WizardActive ? state as WizardActive : null;

  void setHeight(num? v) =>
      _emitActive((s) => s.copyWith(answers: s.answers.copyWith(heightCm: v)));
  void setWeight(num? v) =>
      _emitActive((s) => s.copyWith(answers: s.answers.copyWith(weightKg: v)));
  void setSport(String? v) => _emitActive(
      (s) => s.copyWith(answers: s.answers.copyWith(sportFrequency: v)));
  void setSmoking(String? v) => _emitActive(
      (s) => s.copyWith(answers: s.answers.copyWith(smokingStatus: v)));
  void setAlcohol(String? v) => _emitActive(
      (s) => s.copyWith(answers: s.answers.copyWith(alcoholFrequency: v)));

  void _emitActive(WizardActive Function(WizardActive) update) {
    final s = _active;
    if (s == null) return;
    emit(update(s));
  }

  /// Advance to the next step. Persists vitals/lifestyle when leaving steps
  /// 0..4 (the input steps the wizard "owns"). Steps 5..9 are record-based
  /// (allergies/conditions/etc.) and persistence is handled by HealthCubit
  /// directly within those step widgets.
  ///
  /// On reaching the last input step, calls complete_health_profile() and
  /// transitions to WizardCompleted.
  Future<void> next() async {
    final s = _active;
    if (s == null) return;

    final a = s.answers;
    try {
      switch (s.stepIndex) {
        case 0:
          await _repo.upsertVitalsLifestyle(heightCm: a.heightCm);
          break;
        case 1:
          await _repo.upsertVitalsLifestyle(weightKg: a.weightKg);
          break;
        case 2:
          await _repo.upsertVitalsLifestyle(sportFrequency: a.sportFrequency);
          break;
        case 3:
          await _repo.upsertVitalsLifestyle(smokingStatus: a.smokingStatus);
          break;
        case 4:
          await _repo.upsertVitalsLifestyle(alcoholFrequency: a.alcoholFrequency);
          break;
        // 5..9 are record-based; HealthCubit handles persistence directly.
      }
    } catch (e) {
      emit(WizardError(e.toString()));
      return;
    }

    if (s.stepIndex >= kWizardTotalInputSteps - 1) {
      emit(s.copyWith(submittingFinal: true));
      try {
        final r = await _repo.completeHealthProfile();
        emit(WizardCompleted(
          alreadyAwarded: r.alreadyAwarded,
          newBalance: r.newBalance,
        ));
      } catch (e) {
        emit(WizardError(e.toString()));
      }
      return;
    }

    emit(s.copyWith(stepIndex: s.stepIndex + 1));
  }

  void back() {
    final s = _active;
    if (s == null || s.stepIndex == 0) return;
    emit(s.copyWith(stepIndex: s.stepIndex - 1));
  }

  /// Skip is functionally equivalent to next() with the current (possibly null) answer.
  Future<void> skip() => next();
}
