// lib/services/notifications/notification_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:pushy_flutter/pushy_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:docsera/screens/home/messages/conversation/conversation_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:docsera/Business_Logic/Messages_page/conversation_cubit.dart';
import 'package:docsera/services/supabase/supabase_conversation_service.dart';
import 'package:docsera/services/navigation/app_lifecycle.dart';
import 'package:docsera/widgets/custom_bottom_navigation_bar.dart';
import 'package:docsera/Business_Logic/Health_page/patient_switcher_cubit.dart';
import 'package:docsera/screens/home/health/pages/visit_reports/visit_reports_page.dart';
import 'package:docsera/screens/home/loyalty/vouchers_page.dart';
import 'package:docsera/screens/home/connections/link_request_review_page.dart';
import 'package:docsera/screens/home/account/pending_deletion_page.dart';
import 'package:docsera/services/notifications/in_app_notification_banner.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  String? _pushyDeviceToken;

  static const AndroidNotificationChannel _defaultChannel = AndroidNotificationChannel(
    'docsera_default',
    'General Notifications',
    description: 'General notifications for DocSera',
    importance: Importance.high,
  );

  GlobalKey<NavigatorState>? navigatorKey;

  Future<void> init({required GlobalKey<NavigatorState> navKey}) async {
    navigatorKey = navKey;
    if (_initialized) return;

    // 1) Timezones
    tz.initializeTimeZones();
    // استخدم أي fallback منطقي لبيئتك
    tz.setLocalLocation(tz.getLocation(_fallbackTz()));

    // 2) تهيئة flutter_local_notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    // Register a notification category for the T-30m appointment reminder
    // with two actions: call the clinic and open Maps for directions.
    // The action IDs are matched in _handleNotificationResponse to dispatch
    // platform-channel intents.
    final iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
      notificationCategories: <DarwinNotificationCategory>[
        DarwinNotificationCategory(
          _appointmentT30CategoryId,
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain(
              _actionCallClinic,
              '☎ اتصل بالعيادة',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              _actionDirections,
              '📍 الاتجاهات',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
        ),
      ],
    );

    final settings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _fln.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // قناة أندرويد
    await _fln
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_defaultChannel);

    // 3) iOS authorization. Request again explicitly + log the resulting
    // status so the next time scheduled reminders mysteriously don't fire
    // we know whether the OS actually authorized us.
    final iosPlugin = _fln
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      final status = await iosPlugin.checkPermissions();
      debugPrint(
          '🔔 iOS local-notification authorization — requested=$granted, '
          'status: alert=${status?.isAlertEnabled}, '
          'sound=${status?.isSoundEnabled}, '
          'badge=${status?.isBadgeEnabled}, '
          'critical=${status?.isCriticalEnabled}, '
          'enabled=${status?.isEnabled}');
    }

    // Same for Android — log permission state. Required from API 33+.
    final androidPlugin = _fln
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final notifEnabled = await androidPlugin.areNotificationsEnabled();
      debugPrint('🔔 Android notif perms — enabled=$notifEnabled');
      if (notifEnabled == false) {
        await androidPlugin.requestNotificationsPermission();
      }
    }

    // 4) Pushy (مهم: تأكد من استدعاء Pushy.listen() في main.dart داخل initState)
    await _initPushy();

    _initialized = true;
  }

  /// Schedule a smoke-test reminder N seconds from now. Used by the prefs
  /// screen's "Send test notification" button so you can verify the
  /// schedule pipeline end-to-end without waiting 30 minutes.
  Future<void> sendTestReminder({int delaySeconds = 5}) async {
    final whenLocal = DateTime.now().add(Duration(seconds: delaySeconds));
    debugPrint('🧪 sendTestReminder scheduling for $whenLocal');
    // OS-scheduled notification — delivered on the lock screen if the
    // app is backgrounded by the time it fires.
    await _scheduleWithId(
      id: 999001,
      whenLocal: whenLocal,
      title: 'DocSera',
      body: 'Test reminder — your reminder pipeline is working ✅',
      timeSensitive: true,
      payload: 'appointment:test',
    );
    final pending = await _fln.pendingNotificationRequests();
    debugPrint(
        '🧪 pending after test schedule: ${pending.length} ids=${pending.map((p) => p.id).toList()}');
    // Foreground-only in-app banner. Fires in parallel with the OS
    // schedule. If the app is foregrounded when this fires, render the
    // banner; if backgrounded, the OS notification covers it.
    scheduleForegroundBanner(
      key: 'test',
      delay: Duration(seconds: delaySeconds),
      title: 'DocSera',
      body: 'Test reminder — your reminder pipeline is working ✅',
      payload: 'appointment:test',
    );
  }

  // -------------------------------------------------------------------------
  // Parallel foreground-banner scheduling
  // -------------------------------------------------------------------------
  // Pushy installs itself as the iOS UNUserNotificationCenter delegate and
  // suppresses foreground presentation for OS-scheduled notifications. To
  // give the user something to see while the app is open, we schedule a
  // Dart Timer that fires at the same moment and renders an in-app banner
  // overlay. Background delivery is unaffected — the OS notification still
  // fires on the lock screen.

  final Map<String, Timer> _foregroundTimers = {};
  // Per-key memory of the fire-time we last delivered a banner for.
  // Reconcile re-runs on app resume (and on cubit refresh) — without this
  // we'd re-deliver the same banner every time. Resetting on cancel /
  // when the fireTime changes (reschedule) lets us re-fire for genuinely
  // new schedules.
  final Map<String, DateTime> _firedFireTimes = {};

  /// Idempotent scheduling helper that:
  ///   - cancels any existing timer for [key]
  ///   - if [fireTime] is in the future: arms a Timer to fire the banner
  ///   - if [fireTime] is in the past but within the last 60 seconds AND
  ///     we haven't already fired for this exact moment: fires immediately
  ///   - if [fireTime] is older than 60s in the past: skips silently
  ///
  /// The "fired this exact moment" memory uses the fireTime value, so a
  /// reschedule that changes fireTime will re-fire as needed.
  void scheduleOrFireForegroundBanner({
    required String key,
    required DateTime fireTime,
    required String title,
    required String body,
    String? payload,
  }) {
    if (!Platform.isIOS) return;
    _foregroundTimers.remove(key)?.cancel();
    final now = DateTime.now();
    final delta = fireTime.difference(now);

    if (delta.isNegative) {
      // Already passed. Within tolerance, fire now if we haven't already
      // for this fireTime; otherwise drop.
      if (delta.inSeconds.abs() > 60) {
        if (kDebugMode) {
          debugPrint('🔔 banner $key: too late ($delta), skipping');
        }
        return;
      }
      final lastFired = _firedFireTimes[key];
      if (lastFired != null && lastFired.isAtSameMomentAs(fireTime)) {
        if (kDebugMode) {
          debugPrint('🔔 banner $key: already fired for $fireTime');
        }
        return;
      }
      _firedFireTimes[key] = fireTime;
      if (kDebugMode) {
        debugPrint('🔔 banner $key: firing now (was due $delta ago)');
      }
      showInAppBannerNow(title: title, body: body, payload: payload);
      return;
    }

    // Future moment — arm a Timer.
    _foregroundTimers[key] = Timer(delta, () {
      _foregroundTimers.remove(key);
      _firedFireTimes[key] = fireTime;
      if (kDebugMode) debugPrint('🔔 banner $key: firing on schedule');
      showInAppBannerNow(title: title, body: body, payload: payload);
    });
  }

  /// Backwards-compatible delay-based wrapper. Used by sendTestReminder.
  void scheduleForegroundBanner({
    required String key,
    required Duration delay,
    required String title,
    required String body,
    String? payload,
  }) {
    if (!Platform.isIOS) return;
    final fireTime = DateTime.now().add(delay);
    scheduleOrFireForegroundBanner(
      key: key,
      fireTime: fireTime,
      title: title,
      body: body,
      payload: payload,
    );
  }

  /// Show the foreground in-app banner immediately. Used by the
  /// realtime-driven path in NotificationsCubit when a new push arrives
  /// and the row appears in public.notifications. Guarded by:
  ///   - Platform.isIOS (Android handles foreground itself via heads-up)
  ///   - currentContext mounted (app is alive in this isolate)
  ///   - WidgetsBinding lifecycle == resumed (app is actually foreground)
  void showInAppBannerNow({
    required String title,
    required String body,
    String? payload,
  }) {
    if (!Platform.isIOS) return;
    final ctx = navigatorKey?.currentContext;
    if (ctx == null || !ctx.mounted) {
      debugPrint('🔔 foreground banner skipped (no live context)');
      return;
    }
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != AppLifecycleState.resumed) {
      debugPrint('🔔 foreground banner skipped (app state=$state)');
      return;
    }
    InAppNotificationBanner.show(
      ctx,
      title: title,
      body: body,
      payload: payload,
    );
  }

  void cancelForegroundBanner(String key) {
    _foregroundTimers.remove(key)?.cancel();
  }

  void cancelAllForegroundBanners() {
    for (final t in _foregroundTimers.values) {
      t.cancel();
    }
    _foregroundTimers.clear();
  }

  Future<void> _initPushy() async {
    // Pushy's iOS SDK installs itself as the UNUserNotificationCenter
    // delegate. By default, that means foreground notifications are
    // suppressed (Pushy returns no presentation options to iOS). Flip
    // on Pushy's built-in foreground in-app banner so users see the
    // notification while the app is running. Without this, T-30m / T-24h
    // appointment reminders (and any push received in foreground) only
    // appear if the user happens to have backgrounded the app at the
    // exact moment delivery fires.
    if (Platform.isIOS) {
      Pushy.toggleInAppBanner(true);
    }

    // استقبال الإشعارات (خلفية/مقدمة)
    Pushy.setNotificationListener(backgroundNotificationListener);

    // Start listening for notifications
    Pushy.listen();


    // عند الضغط على الإشعار
    Pushy.setNotificationClickListener((Map<String, dynamic> data) {
      final payload = (data['payload'] ?? '') as String?;
      _handleNotificationTap(payload);
      // امسح الشارة على iOS
      Pushy.clearBadge();
    });

    try {
      // تسجيل الجهاز والحصول على التوكن
      final token = await Pushy.register();
      // Don't log the device token — it's a credential that can be used to push to this device.
      if (kDebugMode) debugPrint('✅ Pushy Registration Success (token length=${token.length})');
      _pushyDeviceToken = token;

      // بانر داخل التطبيق على iOS (اختياري)
      if (Platform.isIOS) {
        Pushy.toggleInAppBanner(false);
        // لا توجد setBadge في Pushy؛ استخدم clearBadge لمسح الشارة
        Pushy.clearBadge();
      }

      await _saveDeviceTokenToSupabase(token);
    } catch (e) {
      // يمكنك تسجيل الخطأ
      debugPrint('❌ Pushy register error: $e');
    }
  }

  Future<void> _saveDeviceTokenToSupabase(String token) async {
    final session = Supabase.instance.client.auth.currentSession;
    final userId = session?.user.id;
    if (userId == null) return;

    await Supabase.instance.client.from('user_devices').upsert({
      'user_id': userId,
      'token': token,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'app': 'docsera',
      'locale': _currentLocale(),
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,token,app');

    if (kDebugMode) debugPrint('✅ Pushy Token saved to Supabase');
  }

  /// Best-effort current locale read. Used by _saveDeviceTokenToSupabase
  /// at registration time and by updateDeviceLocale() when the user
  /// changes their language preference. Falls back to 'ar' (project
  /// default) when no navigator context is available.
  String _currentLocale() {
    try {
      final ctx = navigatorKey?.currentContext;
      if (ctx != null) {
        return Localizations.localeOf(ctx).languageCode;
      }
    } catch (_) {/* no-op */}
    return 'ar';
  }

  /// Update user_devices.locale for the currently-registered device.
  /// Called by the language-switcher after the user picks a new locale,
  /// so the next push from the edge function fires in their language
  /// without waiting for them to restart the app.
  Future<void> updateDeviceLocale(String localeCode) async {
    final token = _pushyDeviceToken;
    final session = Supabase.instance.client.auth.currentSession;
    final userId = session?.user.id;
    if (token == null || userId == null) return;
    try {
      await Supabase.instance.client
          .from('user_devices')
          .update({'locale': localeCode})
          .eq('user_id', userId)
          .eq('token', token)
          .eq('app', 'docsera');
      if (kDebugMode) {
        debugPrint('🌐 user_devices.locale → $localeCode');
      }
    } catch (e) {
      debugPrint('❌ updateDeviceLocale failed: $e');
    }
  }

  Future<void> deleteToken() async {
    final token = _pushyDeviceToken;
    if (token == null) return;

    try {
      await Supabase.instance.client
          .from('user_devices')
          .delete()
          .eq('token', token)
          .eq('app', 'docsera');

      if (kDebugMode) debugPrint('🗑️ Pushy Token deleted from Supabase');
      _pushyDeviceToken = null;
    } catch (e) {
      debugPrint('❌ Error deleting Pushy token: $e');
    }
  }

  Future<void> showLocal({
    required String title,
    required String body,
    String? payload,
  }) async {
    debugPrint("🔔 NotificationService: showLocal called for '$title'");
    try {
      final android = AndroidNotificationDetails(
        _defaultChannel.id,
        _defaultChannel.name,
        channelDescription: _defaultChannel.description,
        importance: Importance.max, // Max importance
        priority: Priority.high,
        playSound: true,
      );

      const ios = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active, // Force active interruption
      );

      await _fln.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        NotificationDetails(android: android, iOS: ios),
        payload: payload,
      );
      debugPrint("✅ NotificationService: _fln.show completed");
    } catch (e) {
      debugPrint("❌ NotificationService: Error showing local notification: $e");
    }
  }

  Future<void> scheduleReminder({
    required DateTime whenLocal,
    required String title,
    required String body,
    String? payload,
    bool allowWhileIdle = true,
  }) async {
    if (whenLocal.isBefore(DateTime.now())) return;

    final android = AndroidNotificationDetails(
      _defaultChannel.id,
      _defaultChannel.name,
      channelDescription: _defaultChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // ملاحظة: في v18+ تم حذف uiLocalNotificationDateInterpretation و enum المرتبط
    await _fln.zonedSchedule(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      tz.TZDateTime.from(whenLocal, tz.local),
      NotificationDetails(android: android, iOS: ios),
      androidScheduleMode: allowWhileIdle
          ? AndroidScheduleMode.inexactAllowWhileIdle
          : AndroidScheduleMode.inexact,
      // لا ترسل هذا البراميتر بعد الآن:
      // uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  /// Public deep-link entry point. Used by the in-app inbox so that
  /// tap-from-row reuses exactly the same navigation logic as tap-from-push.
  /// Adding a new destination should always be done in this method, not
  /// duplicated at call sites.
  Future<void> handleDeepLink(String? payload) async {
    _handleNotificationTap(payload);
  }

  /// Routes the user-tap on a local notification: either the body
  /// (resp.actionId is null → existing deep-link logic) or one of the
  /// registered action buttons (call clinic, directions).
  void _handleNotificationResponse(NotificationResponse resp) {
    final actionId = resp.actionId;
    final payload = resp.payload;
    if (actionId == null || actionId.isEmpty) {
      _handleNotificationTap(payload);
      return;
    }
    // Action taps for the T-30m reminder. Both actions need the
    // appointment ID so we can fetch phone / location at handle time.
    if (payload != null && payload.startsWith('appointment:')) {
      final appointmentId = payload.substring('appointment:'.length);
      switch (actionId) {
        case _actionCallClinic:
          _dispatchCallClinic(appointmentId);
          return;
        case _actionDirections:
          _dispatchDirections(appointmentId);
          return;
      }
    }
    // Unknown action — fall back to default tap behavior.
    _handleNotificationTap(payload);
  }

  Future<void> _dispatchCallClinic(String appointmentId) async {
    try {
      final row = await Supabase.instance.client
          .from('appointments')
          .select('clinic_address')
          .eq('id', appointmentId)
          .maybeSingle();
      final addr = row?['clinic_address'];
      String? phone;
      if (addr is Map) {
        phone = (addr['phone'] ?? addr['phone_number'] ?? addr['contact_phone'])
            ?.toString();
      }
      if (phone == null || phone.isEmpty) {
        debugPrint('☎ no phone in clinic_address for $appointmentId');
        return;
      }
      final telUri = Uri.parse('tel:${phone.replaceAll(RegExp(r"\s+"), "")}');
      if (await launcher.canLaunchUrl(telUri)) {
        await launcher.launchUrl(telUri);
      } else {
        debugPrint('☎ canLaunchUrl false for $telUri');
      }
    } catch (e) {
      debugPrint('☎ call clinic dispatch error: $e');
    }
  }

  Future<void> _dispatchDirections(String appointmentId) async {
    try {
      final row = await Supabase.instance.client
          .from('appointments')
          .select('location, clinic_address')
          .eq('id', appointmentId)
          .maybeSingle();
      Uri? uri;
      final loc = row?['location'];
      if (loc is Map) {
        final lat = loc['lat'] ?? loc['latitude'];
        final lng = loc['lng'] ?? loc['longitude'] ?? loc['lon'];
        if (lat != null && lng != null) {
          uri = Uri.parse(
              'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
        }
      }
      if (uri == null) {
        final addr = row?['clinic_address'];
        if (addr is Map) {
          final text = (addr['address'] ?? addr['street'] ?? addr['name'])
              ?.toString();
          if (text != null && text.isNotEmpty) {
            uri = Uri.parse(
                'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(text)}');
          }
        }
      }
      if (uri == null) {
        debugPrint('📍 no location/address for $appointmentId');
        return;
      }
      if (await launcher.canLaunchUrl(uri)) {
        await launcher.launchUrl(uri,
            mode: launcher.LaunchMode.externalApplication);
      } else {
        debugPrint('📍 canLaunchUrl false for $uri');
      }
    } catch (e) {
      debugPrint('📍 directions dispatch error: $e');
    }
  }

  // ---------------------------------------------------------------------
  // Appointment-reminder helpers (used by AppointmentReminderScheduler).
  // Deterministic IDs derived from appointment_id keep cancel/reschedule
  // idempotent across app launches.
  // ---------------------------------------------------------------------

  static int _reminderId(String appointmentId, String suffix) {
    // hashCode is signed 64-bit on Dart; clamp to a safe positive 31-bit
    // range so flutter_local_notifications (Android int32) doesn't choke.
    final raw = '$appointmentId|$suffix'.hashCode;
    return raw & 0x7FFFFFFF;
  }

  /// Schedule the T-24h and T-30m reminders for one appointment.
  /// Cancels any existing reminders for the same appointment first so
  /// reschedule loops are idempotent.
  Future<void> scheduleAppointmentReminders({
    required String appointmentId,
    required DateTime appointmentLocal,
    required String reminder24Title,
    required String reminder24Body,
    required String reminder30Title,
    required String reminder30Body,
  }) async {
    await cancelAppointmentReminders(appointmentId);

    final t24 = appointmentLocal.subtract(const Duration(hours: 24));
    final t30 = appointmentLocal.subtract(const Duration(minutes: 30));
    final now = DateTime.now();
    final payload = 'appointment:$appointmentId';

    if (kDebugMode) {
      debugPrint(
          '⏰ scheduleAppointmentReminders($appointmentId): now=$now, '
          'appt=$appointmentLocal, t24=$t24 (future=${t24.isAfter(now)}), '
          't30=$t30 (future=${t30.isAfter(now)})');
    }

    // OS notification: only schedule if in the future (iOS won't accept
    // past timestamps). The foreground banner separately handles the
    // "moment just passed" case via scheduleOrFireForegroundBanner.
    if (t24.isAfter(now)) {
      await _scheduleWithId(
        id: _reminderId(appointmentId, 't24'),
        whenLocal: t24,
        title: reminder24Title,
        body: reminder24Body,
        timeSensitive: false,
        payload: payload,
      );
    }
    scheduleOrFireForegroundBanner(
      key: 'apt-$appointmentId-t24',
      fireTime: t24,
      title: reminder24Title,
      body: reminder24Body,
      payload: payload,
    );

    if (t30.isAfter(now)) {
      await _scheduleWithId(
        id: _reminderId(appointmentId, 't30'),
        whenLocal: t30,
        title: reminder30Title,
        body: reminder30Body,
        timeSensitive: true,
        payload: payload,
      );
    }
    scheduleOrFireForegroundBanner(
      key: 'apt-$appointmentId-t30',
      fireTime: t30,
      title: reminder30Title,
      body: reminder30Body,
      payload: payload,
    );

    if (kDebugMode) {
      final pending = await _fln.pendingNotificationRequests();
      debugPrint(
          '⏰ pending count after schedule: ${pending.length} '
          '— ids: ${pending.map((p) => p.id).toList()}');
    }
  }

  Future<void> cancelAppointmentReminders(String appointmentId) async {
    await _fln.cancel(_reminderId(appointmentId, 't24'));
    await _fln.cancel(_reminderId(appointmentId, 't30'));
    cancelForegroundBanner('apt-$appointmentId-t24');
    cancelForegroundBanner('apt-$appointmentId-t30');
    _firedFireTimes.remove('apt-$appointmentId-t24');
    _firedFireTimes.remove('apt-$appointmentId-t30');
  }

  Future<void> _scheduleWithId({
    required int id,
    required DateTime whenLocal,
    required String title,
    required String body,
    required bool timeSensitive,
    String? payload,
  }) async {
    final android = AndroidNotificationDetails(
      _defaultChannel.id,
      _defaultChannel.name,
      channelDescription: _defaultChannel.description,
      importance: timeSensitive ? Importance.max : Importance.high,
      priority: timeSensitive ? Priority.max : Priority.high,
      fullScreenIntent: timeSensitive,
      playSound: true,
      actions: timeSensitive
          ? <AndroidNotificationAction>[
              const AndroidNotificationAction(
                _actionCallClinic,
                '☎ اتصل بالعيادة',
                showsUserInterface: true,
                cancelNotification: true,
              ),
              const AndroidNotificationAction(
                _actionDirections,
                '📍 الاتجاهات',
                showsUserInterface: true,
                cancelNotification: true,
              ),
            ]
          : null,
    );

    final ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: timeSensitive
          ? InterruptionLevel.timeSensitive
          : InterruptionLevel.active,
      categoryIdentifier:
          timeSensitive ? _appointmentT30CategoryId : null,
    );

    final tzWhen = tz.TZDateTime.from(whenLocal, tz.local);
    try {
      await _fln.zonedSchedule(
        id,
        title,
        body,
        tzWhen,
        NotificationDetails(android: android, iOS: ios),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
      if (kDebugMode) {
        debugPrint(
            '⏰ zonedSchedule OK: id=$id, when=$tzWhen, '
            'title="$title", timeSensitive=$timeSensitive');
      }
    } catch (e, st) {
      debugPrint('❌ zonedSchedule FAILED for id=$id: $e\n$st');
      rethrow;
    }
  }

  /// iOS notification category ID for appointment T-30m reminders. Two
  /// actions: dial the clinic, open Maps for directions. Registered in
  /// init() via DarwinInitializationSettings.notificationCategories.
  static const String _appointmentT30CategoryId = 'appointment_t30_actions';
  static const String _actionCallClinic = 'action_call_clinic';
  static const String _actionDirections = 'action_directions';

  void _handleNotificationTap(String? payload) async {
    debugPrint("👆 Notification Tapped with payload: $payload");
    
    // ✅ Clear all notifications from center when app is opened via notification
    await _fln.cancelAll();
    
    // Clear Badge
    if (Platform.isIOS) {
      Pushy.clearBadge();
    }
    if (payload == null || payload.isEmpty) return;
    
    // ✅ Wait for Main Screen to be ready (Cold Start Fix)
    await AppLifecycle.waitForAppReady();

    debugPrint("🔔 Notification Tapped with payload: $payload");

    final nav = navigatorKey?.currentState;
    if (nav == null) {
      debugPrint("⚠️ Navigator State is null, cannot navigate");
      return;
    }

    if (payload.startsWith('conversation:')) {
      final conversationId = payload.split(':').last;
      
      try {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null) return;

        // ✅ FIX: Clear stack & Switch to Messages Tab
        final navState = navigatorKey?.currentState;
        if (navState != null) {
          navState.popUntil((route) => route.isFirst);

          final mainScreenState = CustomBottomNavigationBar.globalKey.currentState;
          if (mainScreenState != null) {
            mainScreenState.switchTab(3); // Index 3 = Messages
          }
        }
        
        // Small delay to ensure tab switch completes
        await Future.delayed(const Duration(milliseconds: 150));

        final response = await Supabase.instance.client
            .from('conversations')
            .select()
            .eq('id', conversationId)
            .maybeSingle();

        if (response != null) {
          final doctorName = response['doctor_name'] ?? 'Doctor';
          final patientName = response['patient_name'] ?? 'Patient';
          final accountHolder = response['account_holder_name'] ?? patientName;
          
          final String? docUrl = response['doctor_image'];
          final ImageProvider avatar = (docUrl != null && docUrl.isNotEmpty)
              ? NetworkImage(docUrl)
              : const NetworkImage('https://via.placeholder.com/150');

          navigatorKey?.currentState?.push(
            MaterialPageRoute(
              builder: (_) => BlocProvider(
                create: (_) => ConversationCubit(ConversationService()),
                child: ConversationPage(
                  conversationId: conversationId,
                  doctorName: doctorName,
                  doctorAvatar: avatar,
                  accountHolderName: accountHolder,
                  patientName: patientName,
                ),
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint("Error navigating to conversation: $e");
      }
    } else if (payload.startsWith('appointment:')) {
        debugPrint("📅 Navigating to Appointments Tab");
        
        final nav = navigatorKey?.currentState;
        if (nav != null) {
          nav.popUntil((route) => route.isFirst);
          
          // ✅ Switch to Appointments Tab (Index 1)
          final mainScreenState = CustomBottomNavigationBar.globalKey.currentState;
          if (mainScreenState != null) {
             mainScreenState.switchTab(1); // Appointments is usually index 1
          }
        }
    } else if (payload.startsWith('document:')) {
        debugPrint("📄 Navigating to Documents");
        
        final nav = navigatorKey?.currentState;
        if (nav != null) {
          nav.popUntil((route) => route.isFirst);
          
           // ✅ Switch to Documents/Health Tab (Index 3 or 2 depending on layout)
           // Assuming Health Page is Index 2
          final mainScreenState = CustomBottomNavigationBar.globalKey.currentState;
          if (mainScreenState != null) {
             mainScreenState.switchTab(2); 
          }
        }
    } else if (payload.startsWith('report:')) {
        debugPrint("📄 Navigating to Visit Reports Page");
        
        final nav = navigatorKey?.currentState;
        if (nav != null) {
          // 1. Parsing Payload: report:recordId:relativeId:patientName
          final parts = payload.split(':'); 
          if (parts.length >= 4) {
             final relativeId = parts[2];
             final patientName = parts[3];
             
             // 2. Switch Patient Context
             final context = navigatorKey?.currentContext;
             if (context != null) {
                 final switcher = context.read<PatientSwitcherCubit>();
                 
                 debugPrint("🔄 Switching patient context to: ${relativeId == 'null' ? 'Main User' : patientName}");
                 
                 if (relativeId == 'null' || relativeId == 'undefined' || relativeId.isEmpty) {
                     switcher.switchToUser();
                 } else {
                     switcher.switchToRelative(
                         relativeId: relativeId, 
                         relativeName: patientName
                     );
                 }
             }
          }

          // Small delay to ensure state propagation
           await Future.delayed(const Duration(milliseconds: 100));

          // 3. Navigate
          nav.push(
            MaterialPageRoute(
               builder: (_) => const VisitReportsPage(),
            ),
          );
        }
    } else if (payload.startsWith('docsera://link-request/')) {
        // Patient↔doctor connection / merge request review.
        // Token is bounded charset + length to refuse malformed deep links
        // before we hit the DB (mirrors isValidDoctorToken).
        final requestId = payload.substring('docsera://link-request/'.length);
        if (requestId.isEmpty || requestId.length > 64 ||
            !RegExp(r'^[A-Za-z0-9_\-]+$').hasMatch(requestId)) {
          debugPrint("⚠️ Rejected link-request deep link with invalid token shape");
          return;
        }
        debugPrint("🤝 Navigating to LinkRequestReviewPage for $requestId");
        nav.popUntil((route) => route.isFirst);
        nav.push(
          MaterialPageRoute(
            builder: (_) => LinkRequestReviewPage(requestId: requestId),
          ),
        );
    } else if (payload.startsWith('voucher:')) {
        debugPrint("🎁 Navigating to Vouchers / Wallet");
        nav.popUntil((route) => route.isFirst);
        nav.push(
          MaterialPageRoute(
            builder: (_) => const VouchersPage(),
          ),
        );
    } else if (payload.startsWith('account_deletion:')) {
        debugPrint("⚠️ Navigating to Pending Deletion page");
        nav.popUntil((route) => route.isFirst);
        nav.push(
          MaterialPageRoute(
            builder: (_) => const PendingDeletionPage(),
          ),
        );
    } else if (payload.startsWith('account:')) {
        debugPrint("👤 Navigating to Account tab");
        nav.popUntil((route) => route.isFirst);
        final mainScreenState = CustomBottomNavigationBar.globalKey.currentState;
        if (mainScreenState != null) {
          mainScreenState.switchTab(4);
        }
    }
  }

  Future<void> clearBadge() async {
    if (Platform.isIOS) {
      // لا يوجد setBadge في Pushy، استخدم clearBadge لمسح العداد
      Pushy.clearBadge();
    }
  }

  /// تفعيل/إيقاف استقبال إشعارات Pushy على هذا الجهاز
  Future<void> setPushEnabled(bool enabled) async {
    try {
      // الطريقة الصحيحة في pushy_flutter هي toggleNotifications
      Pushy.toggleNotifications(enabled);

      if (enabled && _pushyDeviceToken == null) {
        final token = await Pushy.register();
        _pushyDeviceToken = token;
        await _saveDeviceTokenToSupabase(token);
      }

      if (!enabled) {
        _pushyDeviceToken = null;
      }
    } catch (e) {
      debugPrint('setPushEnabled error: $e');
    }
  }

  String _fallbackTz() => 'Asia/Damascus';
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse resp) {
  // لا يوجد context هنا
}

// 🛑 Prevent duplicate notifications (Time-based cache)
Map<String, int> _recentNotifications = {};

@pragma('vm:entry-point')
Future<void> backgroundNotificationListener(Map<String, dynamic> data) async {
  try {
    debugPrint('🔔 Pushy Background Listener Received: $data');
    WidgetsFlutterBinding.ensureInitialized();

    final title = (data['title'] ?? 'DocSera') as String;
    final body = (data['body'] ?? '') as String;
    final payload = (data['payload'] ?? '') as String;
    
    // 🛡️ Enhanced Deduplication (Time-Based)
    final dedupKey = '${title}_$payload';
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Check if seen in the last 5 seconds (5000 ms)
    final lastSeen = _recentNotifications[dedupKey];
    if (lastSeen != null && (now - lastSeen < 5000)) {
       debugPrint("🔕 Duplicate Notification Prevented (Time Window): $dedupKey");
       return;
    }
    _recentNotifications[dedupKey] = now;
    
    // Cleanup old keys occasionally
    _recentNotifications.removeWhere((_, time) => now - time > 10000);


    // ✅ Main Isolate Check: If NotificationService is initialized, the
    // app is in the foreground. Pushy installs itself as the iOS
    // UNUserNotificationCenterDelegate and tells iOS not to present
    // anything in foreground — it just forwards the data to us. Calling
    // _fln.show here would loop back through the same delegate and get
    // suppressed again. Instead, render an in-app banner overlay.
    final ctx = NotificationService.instance.navigatorKey?.currentContext;
    if (ctx != null && ctx.mounted) {
      debugPrint("✅ Foreground notification → in-app banner");
      InAppNotificationBanner.show(
        ctx,
        title: title,
        body: body,
        payload: payload,
      );
      return;
    }

    // -------------------------------------------------------------------------
    // 🌑 Background Isolate Fallback
    // -------------------------------------------------------------------------
    debugPrint("🌑 Using Standalone FLN (Background)");
    final FlutterLocalNotificationsPlugin fln = FlutterLocalNotificationsPlugin();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false, 
      requestBadgePermission: false, 
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: androidInit, iOS: iosInit);
    await fln.initialize(settings);

    const androidDetails = AndroidNotificationDetails(
      'docsera_default',
      'General Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await fln.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );

    if (Platform.isIOS) {
       Pushy.clearBadge();
    }
  } catch (e) {
    debugPrint("❌ Error in backgroundNotificationListener: $e");
  }
}
