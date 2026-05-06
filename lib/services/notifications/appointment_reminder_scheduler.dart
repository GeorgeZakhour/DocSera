// Bridges AppointmentsCubit state changes to NotificationService's
// local-reminder helpers. Schedules T-24h and T-30m reminders for every
// upcoming appointment whose status is not "blocked" (cancelled / rejected
// / done / no_show); cancels them as appointments fall out of the list
// or transition into a blocked status.
//
// Runs entirely on-device. No RPC, no DB write, no edge function — local
// reminders should fire even with no network, which is the whole point.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:docsera/Business_Logic/Appointments_page/appointments_cubit.dart';
import 'package:docsera/Business_Logic/Appointments_page/appointments_state.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/services/notifications/notification_service.dart';
import 'package:docsera/utils/time_utils.dart';

class AppointmentReminderScheduler {
  AppointmentReminderScheduler._();
  static final AppointmentReminderScheduler instance =
      AppointmentReminderScheduler._();

  static const _logTag = '⏰ ReminderScheduler';

  /// Statuses that mean "no reminder should fire". Anything else (pending,
  /// not_arrived, confirmed, empty) is fair game. The earlier strict gate
  /// of "only confirmed" missed the common case where a patient books
  /// just before the appointment slot — the reminder window can pass
  /// before the doctor confirms. Reminding for unconfirmed appointments
  /// is the right tradeoff: if the doctor rejects later, _reconcile drops
  /// the row from upcoming and cancelAppointmentReminders fires.
  static const _blockedStatuses = {
    'cancelled',
    'cancelled_by_doctor',
    'rejected',
    'done',
    'no_show',
  };

  StreamSubscription<AppointmentsState>? _sub;
  // Appointment IDs we've ever scheduled in this session. Used to compute
  // the "stale" set on each reconcile (anything we scheduled but is no
  // longer upcoming → cancel). Across-restart cancellation falls back to
  // the deterministic-ID overwrite in scheduleAppointmentReminders.
  final Set<String> _scheduled = {};

  /// Wires into the AppointmentsCubit emitted by the global MultiBlocProvider.
  /// Call once after the app's root context is available — typically right
  /// after the first frame in main.dart.
  void start(BuildContext context) {
    _sub?.cancel();
    final cubit = context.read<AppointmentsCubit>();
    if (kDebugMode) {
      debugPrint(
          '$_logTag start() — initial state: ${cubit.state.runtimeType}');
    }
    // The captured `context` belongs to MainScreen which lives for the
    // duration of the patient session — these stream callbacks won't
    // outlive its build. The lint is technically right that it's risky
    // generally, but inappropriate here.
    _sub = cubit.stream.listen((state) {
      if (kDebugMode) {
        debugPrint('$_logTag stream emit: ${state.runtimeType}');
      }
      // ignore: use_build_context_synchronously
      if (state is AppointmentsLoaded) {
        // ignore: use_build_context_synchronously
        _reconcile(context, state.upcomingAppointments);
      } else if (state is NotLoggedIn) {
        _cancelAll();
      }
    });
    // Reconcile against the current state so we don't wait for the next emit.
    final current = cubit.state;
    if (current is AppointmentsLoaded) {
      _reconcile(context, current.upcomingAppointments);
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await _cancelAll();
  }

  void _reconcile(
    BuildContext context,
    List<Map<String, dynamic>> upcoming,
  ) {
    final loc = AppLocalizations.of(context);
    if (loc == null) {
      if (kDebugMode) debugPrint('$_logTag reconcile skipped — no AppLocalizations');
      return;
    }
    final localeTag = Localizations.localeOf(context).toLanguageTag();

    if (kDebugMode) {
      debugPrint(
          '$_logTag reconcile: ${upcoming.length} upcoming appointments');
    }

    final seen = <String>{};
    for (final appt in upcoming) {
      final id = appt['id'] as String?;
      if (id == null) continue;

      final status = (appt['status'] as String?) ?? '';
      if (_blockedStatuses.contains(status)) {
        if (kDebugMode) debugPrint('$_logTag $id skip (status=$status)');
        continue;
      }

      final tsRaw = appt['timestamp'] as String?;
      if (tsRaw == null) {
        if (kDebugMode) debugPrint('$_logTag $id skip (no timestamp)');
        continue;
      }
      final whenLocal = DocSeraTime.tryParseToSyria(tsRaw);
      if (whenLocal == null) {
        if (kDebugMode) {
          debugPrint('$_logTag $id skip (timestamp parse failed: $tsRaw)');
        }
        continue;
      }

      final doctorName = (appt['doctor_name'] as String?) ?? '';
      final timeLabel = DateFormat.jm(localeTag).format(whenLocal);

      seen.add(id);
      if (kDebugMode) {
        debugPrint(
            '$_logTag $id schedule (doctor="$doctorName", at=$whenLocal)');
      }
      // Schedule (idempotent — the helper cancels first, then schedules).
      NotificationService.instance.scheduleAppointmentReminders(
        appointmentId: id,
        appointmentLocal: whenLocal,
        reminder24Title: loc.reminder24hTitle,
        reminder24Body: loc.reminder24hBody(doctorName, timeLabel),
        reminder30Title: loc.reminder30mTitle,
        reminder30Body: loc.reminder30mBody(doctorName),
      );
      _scheduled.add(id);
    }

    // Anything we previously scheduled but is no longer upcoming → cancel.
    final stale = _scheduled.difference(seen).toList();
    for (final id in stale) {
      if (kDebugMode) debugPrint('$_logTag $id cancel (no longer upcoming)');
      NotificationService.instance.cancelAppointmentReminders(id);
      _scheduled.remove(id);
    }
  }

  Future<void> _cancelAll() async {
    for (final id in _scheduled.toList()) {
      await NotificationService.instance.cancelAppointmentReminders(id);
    }
    _scheduled.clear();
  }
}
