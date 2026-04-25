// lib/Business_Logic/Health_page/wizard/health_profile_wizard_state.dart
import 'package:equatable/equatable.dart';

class WizardAnswers extends Equatable {
  final num? heightCm;
  final num? weightKg;
  final String? sportFrequency;
  final String? smokingStatus;
  final String? alcoholFrequency;

  const WizardAnswers({
    this.heightCm,
    this.weightKg,
    this.sportFrequency,
    this.smokingStatus,
    this.alcoholFrequency,
  });

  /// Returns a new [WizardAnswers] with any non-null argument replacing the
  /// corresponding field. Passing null is a **no-op** — the existing value
  /// is preserved. This is intentional and matches the server-side
  /// `coalesce(excluded.X, p.X)` partial-save semantics. Clearing fields is
  /// out of scope for the wizard (fill-forward only); a future "edit health
  /// profile" surface will need a dedicated clear method.
  WizardAnswers copyWith({
    num? heightCm,
    num? weightKg,
    String? sportFrequency,
    String? smokingStatus,
    String? alcoholFrequency,
  }) =>
      WizardAnswers(
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        sportFrequency: sportFrequency ?? this.sportFrequency,
        smokingStatus: smokingStatus ?? this.smokingStatus,
        alcoholFrequency: alcoholFrequency ?? this.alcoholFrequency,
      );

  @override
  List<Object?> get props =>
      [heightCm, weightKg, sportFrequency, smokingStatus, alcoholFrequency];
}

abstract class HealthProfileWizardState extends Equatable {
  const HealthProfileWizardState();
  @override
  List<Object?> get props => [];
}

class WizardLoading extends HealthProfileWizardState {
  const WizardLoading();
}

class WizardActive extends HealthProfileWizardState {
  /// 0..(kWizardTotalInputSteps-1) input steps; the wizard transitions to
  /// [WizardCompleted] when advancing past the last input step.
  final int stepIndex;
  final WizardAnswers answers;
  final bool submittingFinal;

  const WizardActive({
    required this.stepIndex,
    required this.answers,
    this.submittingFinal = false,
  });

  WizardActive copyWith({
    int? stepIndex,
    WizardAnswers? answers,
    bool? submittingFinal,
  }) =>
      WizardActive(
        stepIndex: stepIndex ?? this.stepIndex,
        answers: answers ?? this.answers,
        submittingFinal: submittingFinal ?? this.submittingFinal,
      );

  @override
  List<Object?> get props => [stepIndex, answers, submittingFinal];
}

class WizardCompleted extends HealthProfileWizardState {
  final bool alreadyAwarded;
  final int newBalance;
  const WizardCompleted({required this.alreadyAwarded, required this.newBalance});
  @override
  List<Object?> get props => [alreadyAwarded, newBalance];
}

/// Terminal error state. The cubit has no `retry()` in v1 — the wizard
/// page should either pop or call `init()` to restart at step 0.
/// TODO: add a `retry()` that resumes from the failed step.
class WizardError extends HealthProfileWizardState {
  final String message;
  const WizardError(this.message);
  @override
  List<Object?> get props => [message];
}

const int kWizardTotalInputSteps = 10;
