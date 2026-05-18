// lib/services/notifications/notification_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:pushy_flutter/pushy_flutter.dart';
// Firebase Cloud Messaging — preferred push provider where Google Play
// Services is available. Pushy stays as the fallback for non-GMS devices
// (Huawei post-2019, AOSP-only). See _initFcmOrPushy() below.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
import 'package:docsera/screens/home/connections/connections_center_page.dart';
import 'package:docsera/screens/home/account/pending_deletion_page.dart';
import 'package:docsera/services/notifications/in_app_notification_banner.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// The cached push token for this device. Holds either an FCM token
  /// or a Pushy token depending on which provider _initFcmOrPushy()
  /// successfully registered with — see also [_deviceProvider].
  String? _deviceToken;

  /// Which push provider issued [_deviceToken]: 'fcm' or 'pushy'.
  /// Set by _initFcmOrPushy() at app startup based on whether FCM
  /// initialization succeeded. Mirrored to user_devices.provider so
  /// the server-side fanout routes this device through the right API.
  String _deviceProvider = 'pushy';

  /// Public read-only access to the cached device token, regardless of
  /// which provider issued it. Used by the password-change "sign out
  /// other devices" flow to identify which user_devices row to KEEP
  /// when the RPC deletes the rest.
  String? get deviceToken => _deviceToken;

  /// Backward-compatible alias for [deviceToken]. Pre-Stage-3 callers
  /// referenced this name when the only provider was Pushy. New code
  /// should prefer [deviceToken] — the cached value can be an FCM
  /// token too. Kept as a getter to avoid touching every consumer file
  /// in this single migration.
  String? get pushyDeviceToken => _deviceToken;

  /// Which provider registered this device's [deviceToken]. Useful for
  /// callers that need to choose between Pushy- and FCM-specific APIs.
  String get deviceProvider => _deviceProvider;

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
    // Use the flat foreground drawable, not the adaptive ic_launcher
    // wrapper — Android can't render adaptive icons in the
    // notification status bar, leading to a generic placeholder.
    const androidInit = AndroidInitializationSettings('@drawable/ic_notify');

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

    // Cold-start tap on a scheduled local reminder (T-24h / T-30m): the
    // app launches via the notification PendingIntent, but
    // onDidReceiveNotificationResponse does NOT fire on launch — we have
    // to read the launch details explicitly and route after the app is
    // ready. Pushy handles its own cold-start tap via Pushy.listen() so
    // this path only matters for flutter_local_notifications.
    final launchDetails = await _fln.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final resp = launchDetails!.notificationResponse;
      if (resp != null) {
        // Defer until navigator is ready — _handleNotificationResponse
        // already awaits AppLifecycle.waitForAppReady() inside the tap
        // path, so calling it directly is safe.
        unawaited(Future(() => _handleNotificationResponse(resp)));
      }
    }

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

    // 4) Push provider — FCM-first with Pushy fallback. Tries to register
    // with FirebaseMessaging; if that fails for any reason (no Google
    // Play Services, network issue, permission denied, APNs slow on iOS),
    // gracefully falls back to Pushy.register() within the same boot.
    // The choice is mirrored to user_devices.provider so the edge
    // function fanout routes this device through the right API.
    await _initFcmOrPushy();

    // 5) Auth state listener — Pushy.register() runs at app boot, BEFORE
    // login. _saveDeviceTokenToSupabase short-circuits when there's no
    // session, so the row is never written. Without re-saving on login,
    // the user is authenticated but their device has no row in
    // user_devices → push fanout silently drops them. Listen for
    // SIGNED_IN / TOKEN_REFRESHED events and re-save then.
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed ||
          event == AuthChangeEvent.userUpdated) {
        // Self-heal: if Pushy registration failed earlier (common on
        // iOS when permissions or APNs are flaky on first launch), the
        // cached token will be null. ensureDeviceRegistered() retries
        // registration AND upserts the user_devices row in one shot,
        // so a missing row recovers automatically without restart.
        await ensureDeviceRegistered();
        // Realtime force-logout watcher — start one per session.
        _startUserDevicesWatcher();
      } else if (event == AuthChangeEvent.signedOut) {
        await _stopUserDevicesWatcher();
      }
    });

    // Cold-start with a cached session does NOT emit a fresh signedIn
    // event from the SDK — the listener above would never fire and the
    // realtime watcher would never start. Bootstrap it here if a
    // session is already restored.
    if (Supabase.instance.client.auth.currentSession != null) {
      _startUserDevicesWatcher();
      // Belt-and-braces: make sure the user_devices row exists for the
      // restored session. _initPushy() above tries this once on cold
      // start, but iOS Pushy.register() can fail silently when APNs is
      // delayed; this second attempt happens after Supabase is ready.
      unawaited(ensureDeviceRegistered());
    }

    _initialized = true;
  }

  /// Realtime channel that watches user_devices for the current user.
  /// If our row is DELETEd by another session (e.g. password change with
  /// "sign out other devices" toggled on), we sign out immediately so
  /// the user doesn't keep operating on a now-revoked session.
  RealtimeChannel? _userDevicesChannel;

  void _startUserDevicesWatcher() {
    final session = Supabase.instance.client.auth.currentSession;
    final userId = session?.user.id;
    if (userId == null) return;
    _stopUserDevicesWatcher(); // Idempotent — drop any previous channel.

    _userDevicesChannel = Supabase.instance.client
        .channel('user_devices:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'user_devices',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) async {
            // Realtime DELETE payload is the OLD row. Ignore deletes
            // whose token doesn't match ours — we only react to OUR
            // own row going away.
            final oldRow = payload.oldRecord;
            final deletedToken = oldRow['token']?.toString();
            if (deletedToken == null) return;
            if (deletedToken == _deviceToken) {
              if (kDebugMode) {
                debugPrint('🚪 user_devices row deleted remotely — '
                    'signing out');
              }
              try {
                _deviceToken = null;
                await Supabase.instance.client.auth.signOut();
              } catch (e) {
                if (kDebugMode) debugPrint('⚠️ remote-signOut failed: $e');
              }
            }
          },
        )
        .subscribe();
  }

  Future<void> _stopUserDevicesWatcher() async {
    final ch = _userDevicesChannel;
    _userDevicesChannel = null;
    if (ch != null) {
      try {
        await Supabase.instance.client.removeChannel(ch);
      } catch (_) {}
    }
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

  // ---------------------------------------------------------------------
  // FCM-first / Pushy-fallback orchestration
  // ---------------------------------------------------------------------
  //
  // _initFcmOrPushy() is called by init() instead of _initPushy() directly.
  // It tries to register the device with Firebase Cloud Messaging; if that
  // fails (no GMS on Huawei post-2019, network blip, permission denied),
  // it gracefully falls back to Pushy.register(), which doesn't need GMS.
  //
  // The decision is per-device-per-install — once registered, the device
  // sticks with whichever provider won. The choice is persisted to
  // user_devices.provider so the server-side fanout (Stage 3 Gate 2)
  // routes notifications through the right API for this specific device.

  Future<void> _initFcmOrPushy() async {
    String? token;
    bool fcmWorked = false;

    // 1. Try FCM. Wrap in a 5-second timeout — FCM init can hang on
    // iOS when APNs is slow on first launch, or on Android while Google
    // Play Services is updating. Falling back to Pushy is preferable
    // to blocking the entire app boot.
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;

      // Request notification permission. On iOS this triggers the OS
      // dialog if not yet shown; on Android 13+ same. We already
      // request POST_NOTIFICATIONS via flutter_local_notifications
      // below, but doing it here keeps the dialog timing consistent
      // with the legacy Pushy flow that fires on first launch.
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // iOS-specific: FCM token derivation requires Apple to deliver
      // the APNs device token first, which can take 10-30 seconds on
      // a cold first launch (post-permission-grant). Without an APNs
      // token, getToken() hangs forever. Poll getAPNSToken with a
      // 10s budget; bail to Pushy fallback if APNs is still silent.
      // Subsequent launches reuse the cached APNs token and this loop
      // returns immediately.
      if (Platform.isIOS) {
        for (int i = 0; i < 10; i++) {
          final apns = await messaging.getAPNSToken();
          if (apns != null) break;
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      // Fetch the FCM token. 10s timeout — generous enough to cover
      // a slow APNs derivation on iOS first launch, short enough that
      // Pushy fallback kicks in within ~15s total on truly broken FCM
      // environments (Huawei post-2019, network blip).
      token = await messaging
          .getToken()
          .timeout(const Duration(seconds: 10));

      if (token != null && token.isNotEmpty) {
        fcmWorked = true;
        await _setupFcmListeners(messaging);
        debugPrint(
          '✅ FCM registration success (token length=${token.length})',
        );
      } else {
        debugPrint(
          '⚠️ FCM returned null/empty token — falling back to Pushy',
        );
      }
    } catch (e) {
      // Most common cause on Huawei post-2019: Google Play Services
      // missing or unreachable. Pushy works without GMS.
      debugPrint('⚠️ FCM init failed, falling back to Pushy: $e');
      fcmWorked = false;
    }

    if (fcmWorked && token != null) {
      _deviceToken = token;
      _deviceProvider = 'fcm';
      await _saveDeviceTokenToSupabase(token, 'fcm');
    } else {
      // Pushy fallback — _initPushy sets _deviceToken via
      // _saveDeviceTokenToSupabase, and _deviceProvider stays its
      // default 'pushy' (or we set it explicitly inside _initPushy).
      await _initPushy();
    }
  }

  /// Wire up FCM listeners. Mirrors the listener wiring _initPushy()
  /// does for Pushy: foreground messages, tap when app is backgrounded,
  /// cold-start tap (app was killed), token rotation, and the
  /// top-level background isolate handler.
  Future<void> _setupFcmListeners(FirebaseMessaging messaging) async {
    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleFcmForegroundMessage);

    // Notification tap when app is in background but not killed.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final payload = message.data['payload']?.toString();
      _handleNotificationTap(payload);
    });

    // Cold-start tap (app was killed when notification was tapped).
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      final payload = initialMessage.data['payload']?.toString();
      // Defer until navigator is ready — _handleNotificationTap
      // already awaits AppLifecycle.waitForAppReady() internally.
      unawaited(Future(() => _handleNotificationTap(payload)));
    }

    // Background isolate handler — must be a top-level function
    // annotated @pragma('vm:entry-point'). See fcmBackgroundHandler
    // below this class.
    FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler);

    // Token rotation. FCM rotates tokens occasionally (e.g. when Google
    // Play Services updates). Persist the new one so we keep delivering
    // after the rotation.
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      debugPrint('🔄 FCM token refreshed (length=${newToken.length})');
      _deviceToken = newToken;
      try {
        await _saveDeviceTokenToSupabase(newToken, 'fcm');
      } catch (e) {
        debugPrint('❌ FCM token refresh upsert failed: $e');
      }
    });
  }

  /// Foreground FCM message handler. Mirrors what Pushy's
  /// backgroundNotificationListener does when the app is in the
  /// foreground: render the in-app banner (iOS) and ALWAYS write to
  /// the system tray (otherwise nothing appears in the shade when
  /// the user pulls down).
  void _handleFcmForegroundMessage(RemoteMessage message) {
    final title = (message.data['title']
            ?? message.notification?.title
            ?? 'DocSera')
        .toString();
    final body = (message.data['body']
            ?? message.notification?.body
            ?? '')
        .toString();
    final payload = (message.data['payload'] ?? '').toString();

    // In-app glass banner — same pattern as Pushy on iOS. Skipped on
    // Android because the heads-up notification covers the visual gap.
    final ctx = navigatorKey?.currentContext;
    if (ctx != null && ctx.mounted && Platform.isIOS) {
      InAppNotificationBanner.show(
        ctx,
        title: title,
        body: body,
        payload: payload,
      );
    }

    // System-tray entry. Without this, foreground notifications never
    // appear in the pull-down shade. flutter_local_notifications.show()
    // writes directly to the OS regardless of FCM's foreground
    // suppression behavior.
    try {
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
      _fln.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: payload,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ FCM foreground tray show failed: $e');
    }
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
      debugPrint('✅ Pushy Registration Success (token length=${token.length})');
      _deviceToken = token;
      _deviceProvider = 'pushy';

      // بانر داخل التطبيق على iOS (اختياري)
      if (Platform.isIOS) {
        Pushy.toggleInAppBanner(false);
        // لا توجد setBadge في Pushy؛ استخدم clearBadge لمسح الشارة
        Pushy.clearBadge();
      }

      await _saveDeviceTokenToSupabase(token, 'pushy');
    } catch (e) {
      // Unconditional log: failure to register is the most common
      // reason for "I'm logged in but never get pushes" reports, so
      // we want this visible in release builds (Xcode console) too.
      debugPrint('❌ Pushy register error: $e');
    }
  }

  /// Self-healing wrapper around Pushy.register() + Supabase upsert.
  /// Safe to call multiple times — idempotent. Fixes the common iOS
  /// boot-race where Pushy.register() inside _initPushy() failed (APNs
  /// timeout, permission not yet granted, network blip) and the
  /// user_devices row was therefore never written.
  ///
  /// Called from:
  ///   - init() once on cold-start when a session is already restored
  ///   - the auth state listener on signedIn / tokenRefreshed / userUpdated
  Future<void> ensureDeviceRegistered() async {
    final session = Supabase.instance.client.auth.currentSession;
    final userId = session?.user.id;
    if (userId == null) return; // Without a session there's nothing to write.

    var token = _deviceToken;
    if (token == null || token.isEmpty) {
      // Re-register with whichever provider was chosen at app start.
      // We don't try to switch providers here — that decision belongs
      // to _initFcmOrPushy(), which only runs at boot. Mid-session
      // switching would invalidate the existing provider's token and
      // create a stale user_devices row.
      try {
        if (_deviceProvider == 'fcm') {
          token = await FirebaseMessaging.instance.getToken();
          if (token == null || token.isEmpty) {
            debugPrint('⚠️ FCM re-registration returned null token');
            return;
          }
          debugPrint(
            '✅ FCM re-registration success (token length=${token.length})',
          );
        } else {
          token = await Pushy.register();
          debugPrint(
            '✅ Pushy re-registration success (token length=${token.length})',
          );
        }
        _deviceToken = token;
      } catch (e) {
        debugPrint('❌ $_deviceProvider re-registration failed: $e');
        return;
      }
    }

    try {
      await _saveDeviceTokenToSupabase(token, _deviceProvider);
    } catch (e) {
      debugPrint('⚠️ ensureDeviceRegistered upsert failed: $e');
    }
  }

  Future<void> _saveDeviceTokenToSupabase(
    String token, [
    String provider = 'pushy',
  ]) async {
    final session = Supabase.instance.client.auth.currentSession;
    final userId = session?.user.id;
    if (userId == null) {
      // No active session — orphan-clean any stale rows for THIS
      // token so a previous user's notifications don't keep firing on
      // this device. RLS allows DELETE only on rows the current user
      // owns; without a session we can't clean directly here, so we
      // just skip and let the periodic 90-day cron sweep handle it.
      return;
    }

    // Orphan defense: before upserting our own row, drop ANY other
    // user_devices row for this token that points at a different
    // user_id. RLS scopes the delete to rows the current session owns,
    // so we can only clean up tokens that belong to the current user
    // anyway — which catches the common bug (User A signs out without
    // cleanup, User B signs in on the same device, A's row would
    // otherwise survive). Cross-account orphans need the operator-side
    // 90-day prune to fully clean.
    try {
      await Supabase.instance.client
          .from('user_devices')
          .delete()
          .eq('token', token)
          .neq('user_id', userId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ user_devices orphan cleanup failed: $e');
      }
    }

    try {
      await Supabase.instance.client.from('user_devices').upsert({
        'user_id': userId,
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'app': 'docsera',
        // Provider drives per-device routing in fanout (Stage 3). Defaults
        // to 'pushy' for backward compatibility with any legacy code path
        // that calls this method without specifying.
        'provider': provider,
        'locale': _currentLocale(),
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,token,app');
      // Visible in release builds — confirms the device row landed.
      debugPrint('✅ user_devices upsert ok '
          '(provider=$provider, '
          'platform=${Platform.isIOS ? 'ios' : 'android'}, '
          'user=${userId.substring(0, 8)}…)');
    } catch (e) {
      debugPrint('❌ user_devices upsert failed: $e');
      rethrow;
    }
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
    final token = _deviceToken;
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
    final token = _deviceToken;
    if (token == null) return;

    try {
      await Supabase.instance.client
          .from('user_devices')
          .delete()
          .eq('token', token)
          .eq('app', 'docsera');

      if (kDebugMode) debugPrint('🗑️ Device token deleted from Supabase');
      _deviceToken = null;
    } catch (e) {
      debugPrint('❌ Error deleting device token: $e');
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

  /// Schedule the four reminders (T-24h, T-2h, T-30m, T-0) for one
  /// appointment. Cancels any existing reminders for the same appointment
  /// first so reschedule loops are idempotent.
  ///
  /// Importance ladder: T-24h and T-2h are high, T-30m and T-0 are
  /// time-sensitive (break through Focus mode + use the action-buttons
  /// category on iOS).
  Future<void> scheduleAppointmentReminders({
    required String appointmentId,
    required DateTime appointmentLocal,
    required String reminder24Title,
    required String reminder24Body,
    required String reminder2hTitle,
    required String reminder2hBody,
    required String reminder30Title,
    required String reminder30Body,
    required String reminder0Title,
    required String reminder0Body,
  }) async {
    // The fn_cron_appointment_reminders pg_cron job (every minute) is now
    // the single source of truth for the four reminder windows
    // (T-24h, T-2h, T-30m, T-0). It fires via Pushy regardless of app
    // state and the realtime channel surfaces the in-app banner when the
    // app is foregrounded. Keep this method around so the existing
    // AppointmentReminderScheduler bridge still compiles, but make it a
    // no-op apart from cancelling any leftover OS-scheduled reminders
    // that older builds may have left in the pending queue.
    await cancelAppointmentReminders(appointmentId);
    if (kDebugMode) {
      debugPrint(
          '⏰ scheduleAppointmentReminders($appointmentId): server-driven now '
          '— skipping local OS scheduling, leftover pending notifications cleared');
    }
  }

  Future<void> cancelAppointmentReminders(String appointmentId) async {
    for (final suffix in const ['t24', 't2h', 't30', 't0']) {
      await _fln.cancel(_reminderId(appointmentId, suffix));
      cancelForegroundBanner('apt-$appointmentId-$suffix');
      _firedFireTimes.remove('apt-$appointmentId-$suffix');
    }
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
      // CATEGORY_REMINDER lets users whitelist this class of notification
      // in their system DND settings ("Allow reminders to interrupt").
      // Without it, Android groups our reminder under CATEGORY_MESSAGE
      // and DND silently drops it. Pair with importance.max + priority.max
      // + fullScreenIntent on the T-30m reminder for max visibility.
      category: timeSensitive
          ? AndroidNotificationCategory.reminder
          : null,
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
             // Re-read from navigatorKey on each invocation: context is fresh
             // at the moment of use (no async gap from here to .read below),
             // but the analyzer's heuristic can't see through the closure
             // capture so we suppress the lint at the call site.
             final context = navigatorKey?.currentContext;
             if (context != null) {
                 // ignore: use_build_context_synchronously
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
        debugPrint("🤝 Navigating to ConnectionsCenterPage for $requestId");
        // Land on the unified Connections Center scrolled to the
        // requested id — calmer surface than pushing the dedicated
        // review page directly. Users still get full details by
        // tapping "see full details" on the focused card, which
        // pushes [LinkRequestReviewPage] (kept reachable for the
        // rich data-flow context).
        nav.popUntil((route) => route.isFirst);
        nav.push(
          MaterialPageRoute(
            builder: (_) => ConnectionsCenterPage(
              entry: ConnectionsCenterEntry.fromNotification,
              focusedRequestId: requestId,
            ),
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

  /// تفعيل/إيقاف استقبال الإشعارات على هذا الجهاز
  ///
  /// Pushy-specific: this calls Pushy.toggleNotifications(). For FCM-
  /// registered devices, mute/unmute happens via the server-side
  /// notification_preferences table (the edge function gates fanout on
  /// those prefs). On FCM, this becomes a no-op rather than fight with
  /// FCM topic management — the prefs system gives finer control anyway.
  Future<void> setPushEnabled(bool enabled) async {
    if (_deviceProvider == 'fcm') {
      if (kDebugMode) {
        debugPrint(
          '⏭️ setPushEnabled($enabled): device on FCM, use prefs instead',
        );
      }
      return;
    }
    try {
      // الطريقة الصحيحة في pushy_flutter هي toggleNotifications
      Pushy.toggleNotifications(enabled);

      if (enabled && _deviceToken == null) {
        final token = await Pushy.register();
        _deviceToken = token;
        await _saveDeviceTokenToSupabase(token, 'pushy');
      }

      if (!enabled) {
        _deviceToken = null;
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
    // app is in the foreground (or backgrounded but not killed).
    final ctx = NotificationService.instance.navigatorKey?.currentContext;
    if (ctx != null && ctx.mounted) {
      // (1) Render the in-app glass banner — only meaningful on iOS where
      //     Pushy's UNUserNotificationCenterDelegate suppresses native
      //     foreground display. On Android the OS-level heads-up still
      //     fires below; the in-app banner is harmless duplication that
      //     the user dismisses by swiping.
      debugPrint("✅ Foreground notification → in-app banner + system tray");
      InAppNotificationBanner.show(
        ctx,
        title: title,
        body: body,
        payload: payload,
      );

      // (2) ALSO display in the system tray. Without this, when the app
      //     is alive (foreground OR backgrounded-but-not-killed), the
      //     Pushy listener fires and we'd return — meaning nothing ever
      //     lands in the notification shade. Users miss the entry on
      //     next pull-down. flutter_local_notifications.show() bypasses
      //     Pushy's delegate and writes directly to the OS shade.
      try {
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
        await NotificationService.instance._fln.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title,
          body,
          const NotificationDetails(android: androidDetails, iOS: iosDetails),
          payload: payload,
        );
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ system-tray show failed: $e');
      }
      return;
    }

    // -------------------------------------------------------------------------
    // 🌑 Background Isolate Fallback
    // -------------------------------------------------------------------------
    debugPrint("🌑 Using Standalone FLN (Background)");
    final FlutterLocalNotificationsPlugin fln = FlutterLocalNotificationsPlugin();

    // Use the flat foreground drawable, not the adaptive ic_launcher
    // wrapper — Android can't render adaptive icons in the
    // notification status bar, leading to a generic placeholder.
    const androidInit = AndroidInitializationSettings('@drawable/ic_notify');
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

// ---------------------------------------------------------------------------
// FCM background message handler
// ---------------------------------------------------------------------------
//
// Runs in a SEPARATE isolate from the main app — has no access to
// NotificationService.instance state. Must be a top-level function
// annotated with @pragma('vm:entry-point') so Flutter's tree-shaker
// preserves it across compilation.
//
// Note on Android dual-display: FCM's documented behavior is that
// when a message includes BOTH `notification` and `data` blocks (which
// our edge function does), the SYSTEM displays the notification
// automatically when the app is in the background, and this isolate
// handler is NOT called. The handler only fires for data-only messages
// or when the app is in the foreground (rare — onMessage handles that).
//
// On iOS, this handler fires only for messages with `content-available: 1`
// (silent background data messages). Apple's notification block always
// goes through the system display path; we don't call the data isolate
// in that case.
//
// In other words: this handler is a defensive net for data-only paths
// the edge function might use in future. Today it rarely fires; the
// system-rendered notification is the primary background path.

/// Dedup state for the FCM background isolate. Lives in its own
/// isolate — does not share with Pushy's _recentNotifications map.
final Map<String, int> _fcmRecentNotifications = {};

@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();

    final title = (message.data['title']
            ?? message.notification?.title
            ?? 'DocSera')
        .toString();
    final body = (message.data['body']
            ?? message.notification?.body
            ?? '')
        .toString();
    final payload = (message.data['payload'] ?? '').toString();

    debugPrint('🔔 FCM background handler fired (title="$title")');

    // Dedup against rapid duplicates from the same logical notification.
    final dedupKey = '${title}_$payload';
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastSeen = _fcmRecentNotifications[dedupKey];
    if (lastSeen != null && (now - lastSeen < 5000)) {
      debugPrint('🔕 Duplicate FCM Notification Prevented: $dedupKey');
      return;
    }
    _fcmRecentNotifications[dedupKey] = now;
    _fcmRecentNotifications.removeWhere((_, time) => now - time > 10000);

    // Render via flutter_local_notifications so the OS shade picks it up
    // even for data-only messages (the path where the system doesn't
    // auto-show). Same channel + icon as our other notification surfaces
    // for visual consistency.
    final FlutterLocalNotificationsPlugin fln =
        FlutterLocalNotificationsPlugin();

    const androidInit = AndroidInitializationSettings('@drawable/ic_notify');
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
  } catch (e) {
    debugPrint('❌ FCM background handler error: $e');
  }
}
