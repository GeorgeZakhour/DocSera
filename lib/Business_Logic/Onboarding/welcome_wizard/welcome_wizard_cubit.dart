import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'welcome_wizard_state.dart';

/// Cubit for the post-signup welcome wizard.
///
/// Owns: current page index, entry mode (firstTime/replay), completion +
/// persistence of `welcome_wizard_completed_v1` in SharedPreferences.
///
/// Persistence is only written in `firstTime` mode — replay-mode runs
/// (launched from the account page) MUST NOT touch the flag.
class WelcomeWizardCubit extends Cubit<WelcomeWizardState> {
  static const String _kFlagKey = 'welcome_wizard_completed_v1';

  final int totalPages;

  WelcomeWizardCubit({
    required WizardEntryMode entryMode,
    required this.totalPages,
  }) : super(WelcomeWizardState(
          currentPage: 0,
          entryMode: entryMode,
          completed: false,
        ));

  /// Advance to the next page. On the last page, marks completion + (in
  /// firstTime mode) persists the flag.
  void next() {
    final nextIndex = state.currentPage + 1;
    if (nextIndex >= totalPages) {
      _markCompleted();
      return;
    }
    emit(state.copyWith(currentPage: nextIndex));
  }

  void previous() {
    if (state.currentPage <= 0) return;
    emit(state.copyWith(currentPage: state.currentPage - 1));
  }

  void jumpTo(int index) {
    if (index < 0 || index >= totalPages) return;
    emit(state.copyWith(currentPage: index));
  }

  /// Skip dismisses the wizard. In firstTime mode this persists the flag
  /// so the user is not shown the wizard again on the next signup-after-
  /// reinstall path. In replay mode it just dismisses (the caller pops).
  void skip() {
    _markCompleted();
  }

  Future<void> _markCompleted() async {
    if (state.entryMode == WizardEntryMode.firstTime) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kFlagKey, true);
    }
    emit(state.copyWith(completed: true));
  }

  /// Read-only check used by the splash / migration logic.
  static Future<bool> hasCompletedWizard() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kFlagKey) ?? false;
  }

  /// One-time migration for existing users who predate the wizard release.
  /// Only sets the flag if it's missing — never overwrites a deliberately
  /// false value (e.g. tests / dev resets).
  static Future<void> migrateExistingUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_kFlagKey)) {
      await prefs.setBool(_kFlagKey, true);
    }
  }
}
