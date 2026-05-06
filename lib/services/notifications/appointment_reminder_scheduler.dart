// Bridges AppointmentsCubit state changes to NotificationService's
// local-reminder helpers. Schedules T-24h and T-30m reminders for every
// upcoming, confirmed appointment; cancels them as appointments leave the
// upcoming list (cancelled, completed, rescheduled).
//
// Runs entirely on-device. No RPC, no DB write, no edge function — local
// reminders should fire even with no network, which is the whole point.

import 'dart:async';

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

  StreamSubscription<AppointmentsState>? _sub;
  // Last-known set of scheduled appointment IDs so we know which
  // reminders to cancel when an appointment falls out of the list.
  final Set<String> _scheduled = {};

  /// Wires into the AppointmentsCubit emitted by the global MultiBlocProvider.
  /// Call once after the app's root context is available — typically right
  /// after the first frame in main.dart.
  void start(BuildContext context) {
    _sub?.cancel();
    final cubit = context.read<AppointmentsCubit>();
    // The captured `context` belongs to MainScreen which lives for the
    // duration of the patient session — these stream callbacks won't
    // outlive its build. The lint is technically right that it's risky
    // generally, but inappropriate here.
    _sub = cubit.stream.listen((state) {
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
    if (loc == null) return;
    final localeTag = Localizations.localeOf(context).toLanguageTag();

    final seen = <String>{};
    for (final appt in upcoming) {
      final id = appt['id'] as String?;
      if (id == null) continue;

      final isConfirmed = (appt['is_confirmed'] as bool?) ?? false;
      final status = (appt['status'] as String?) ?? '';
      // Only schedule for confirmed (or auto-confirmed) appointments — we
      // don't want to remind for pending ones the doctor might still reject.
      if (!isConfirmed && status != 'confirmed') continue;

      final tsRaw = appt['timestamp'] as String?;
      if (tsRaw == null) continue;
      final whenLocal = DocSeraTime.tryParseToSyria(tsRaw);
      if (whenLocal == null) continue;

      final doctorName = (appt['doctor_name'] as String?) ?? '';
      final timeLabel = DateFormat.jm(localeTag).format(whenLocal);

      seen.add(id);
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
