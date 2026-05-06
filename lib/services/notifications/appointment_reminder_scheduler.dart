// Bridges AppointmentsCubit state changes to NotificationService's
// local-reminder helpers. Schedules T-24h and T-30m reminders for every
// upcoming appointment whose status is not "blocked" (cancelled / rejected
// / done / no_show); cancels them as appointments fall out of the list
// or transition into a blocked status.
//
// Runs entirely on-device. No RPC, no DB write, no edge function — local
// reminders should fire even with no network, which is the whole point.
//
// Lifecycle handling: iOS suspends Dart isolates while apps are
// backgrounded, and may even terminate them across long periods. So a
// Dart Timer set 30+ minutes in the future is unreliable — if the user
// switches away and comes back at T-30m, the Timer might never fire.
// To compensate, this class observes WidgetsBinding lifecycle and
// re-runs _reconcile whenever the app is resumed. Reconcile (via
// scheduleAppointmentReminders) handles the "just past" case by firing
// the foreground banner immediately if the moment slipped by within the
// last 60 seconds.

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

class AppointmentReminderScheduler with WidgetsBindingObserver {
  AppointmentReminderScheduler._();
  static final AppointmentReminderScheduler instance =
      AppointmentReminderScheduler._();

  static const _logTag = '⏰ ReminderScheduler';

  /// Statuses that mean "no reminder should fire". Anything else (pending,
  /// not_arrived, confirmed, empty) is fair game.
  static const _blockedStatuses = {
    'cancelled',
    'cancelled_by_doctor',
    'rejected',
    'done',
    'no_show',
  };

  StreamSubscription<AppointmentsState>? _sub;
  BuildContext? _ctx;
  AppointmentsCubit? _cubit;
  bool _observerAttached = false;
  // Appointment IDs we've ever scheduled in this session.
  final Set<String> _scheduled = {};

  /// Wires into the AppointmentsCubit emitted by the global MultiBlocProvider.
  /// Call once after the app's root context is available — typically right
  /// after the first frame in main.dart.
  void start(BuildContext context) {
    _sub?.cancel();
    _ctx = context;
    final cubit = context.read<AppointmentsCubit>();
    _cubit = cubit;

    if (!_observerAttached) {
      WidgetsBinding.instance.addObserver(this);
      _observerAttached = true;
    }

    if (kDebugMode) {
      debugPrint('$_logTag start() — initial state: ${cubit.state.runtimeType}');
    }
    // The captured `context` belongs to MainScreen which lives for the
    // duration of the patient session — these stream callbacks won't
    // outlive its build.
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
    final current = cubit.state;
    if (current is AppointmentsLoaded) {
      _reconcile(context, current.upcomingAppointments);
    } else {
      // Cubit hasn't been loaded yet (user hasn't visited the Appointments
      // tab). Without this, a brand-new appointment booked from elsewhere
      // (e.g. doctor profile) never reaches the scheduler — the cubit's
      // realtime listener is only spun up inside loadAppointments.
      if (kDebugMode) {
        debugPrint(
            '$_logTag start() — cubit not loaded, triggering loadAppointments');
      }
      cubit.loadAppointments(context: context);
    }
  }

  Future<void> stop() async {
    if (_observerAttached) {
      WidgetsBinding.instance.removeObserver(this);
      _observerAttached = false;
    }
    await _sub?.cancel();
    _sub = null;
    _ctx = null;
    _cubit = null;
    await _cancelAll();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // App came back to foreground. iOS may have killed our Dart Timers
    // while we were suspended; re-running reconcile re-arms them and,
    // for any moment that just passed, the "missed-by-< 60s" branch in
    // scheduleAppointmentReminders fires the banner immediately.
    if (kDebugMode) {
      debugPrint('$_logTag app resumed — re-reconciling');
    }
    final ctx = _ctx;
    final cubit = _cubit;
    if (ctx == null || cubit == null) return;
    final cs = cubit.state;
    if (cs is AppointmentsLoaded) {
      _reconcile(ctx, cs.upcomingAppointments);
    }
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
      debugPrint('$_logTag reconcile: ${upcoming.length} upcoming appointments');
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
      if (tsRaw == null) continue;
      final whenLocal = DocSeraTime.tryParseToSyria(tsRaw);
      if (whenLocal == null) continue;

      final doctorName = (appt['doctor_name'] as String?) ?? '';
      final timeLabel = DateFormat.jm(localeTag).format(whenLocal);

      seen.add(id);
      if (kDebugMode) {
        debugPrint('$_logTag $id schedule (doctor="$doctorName", at=$whenLocal)');
      }
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
