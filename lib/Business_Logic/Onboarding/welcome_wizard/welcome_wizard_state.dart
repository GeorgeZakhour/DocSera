import 'package:equatable/equatable.dart';

enum WizardEntryMode { firstTime, replay }

class WelcomeWizardState extends Equatable {
  final int currentPage;
  final WizardEntryMode entryMode;
  final bool completed;

  const WelcomeWizardState({
    required this.currentPage,
    required this.entryMode,
    required this.completed,
  });

  WelcomeWizardState copyWith({int? currentPage, bool? completed}) =>
      WelcomeWizardState(
        currentPage: currentPage ?? this.currentPage,
        entryMode: entryMode,
        completed: completed ?? this.completed,
      );

  @override
  List<Object?> get props => [currentPage, entryMode, completed];
}
