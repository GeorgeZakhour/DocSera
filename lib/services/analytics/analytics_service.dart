// =============================================================================
// Analytics service — the public API used everywhere in the app.
// =============================================================================
//
// Usage:
//   await Analytics.instance.init();          // once, in main()
//   Analytics.instance.track(Events.doctorProfileViewed, {'doctor_id': id});
//   Analytics.instance.identify(userId);      // after login
//   Analytics.instance.reset();               // on logout (new anonymous_id)
//   Analytics.instance.optOut(true);          // GDPR / settings toggle
//
// Design notes:
//   * Anonymous-then-identified flow. anonymous_id is generated once on first
//     launch and persisted across logins. user_id is attached only after auth.
//   * Whitelist enforcement via AnalyticsEventCatalog. Unregistered events and
//     unregistered properties are dropped (with debug-mode warnings).
//   * Offline-first. Events are queued in SharedPreferences and survive kills.
//   * Batched flushing: every 30s OR every 20 events OR on app-background.
//   * Auto-events: app_opened, app_foregrounded/backgrounded, session_start/end,
//     screen_viewed (via AnalyticsNavigatorObserver attached to MaterialApp).
//   * Connectivity-aware: events keep queuing while offline; flush on reconnect.
//
// PHI safety: properties are sanitized in three places — the catalog whitelist,
// the value sanitizer (phone/email regex, 200-char cap), and the DB trigger
// backstop. The SDK refuses to log unregistered events or PII-shaped values.
// =============================================================================

import 'dart:async';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'analytics_event_catalog.dart';
import 'analytics_queue.dart';
import 'analytics_session_tracker.dart';

class Analytics with WidgetsBindingObserver {
  Analytics._();
  static final Analytics instance = Analytics._();

  // ---- persisted identity ----
  static const _kAnonId   = 'analytics_anonymous_id_v1';
  static const _kOptOut   = 'analytics_opt_out_v1';
  static const _kFirstSeen= 'analytics_first_seen_v1';

  // ---- batching policy ----
  static const _flushEvery        = Duration(seconds: 30);
  static const _flushSizeTrigger  = 20;
  static const _maxBatchSize      = 100;

  bool _initialized = false;
  bool _optedOut    = false;
  bool _flushing    = false;

  String? _anonymousId;
  String? _userId;
  String? _currentScreen;
  DateTime? _firstSeenAt;
  StreamSubscription<AuthState>? _authSub;

  // device + app context (resolved once at init)
  String? _appVersion;
  String? _appBuild;
  String? _platform;
  String? _osVersion;
  String? _deviceModel;
  String? _locale;
  String? _timezone;

  final AnalyticsQueue _queue = AnalyticsQueue();
  final AnalyticsSessionTracker _sessions = AnalyticsSessionTracker();
  Timer? _flushTimer;

  SupabaseClient get _supabase => Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Initialize once at app start (after Supabase.initialize). Safe to call
  /// before user is authenticated; user_id is attached later via [identify].
  Future<void> init({String? initialUserId}) async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    _optedOut = prefs.getBool(_kOptOut) ?? false;

    // Anonymous ID: persist once, never change unless reset() is called.
    var anon = prefs.getString(_kAnonId);
    if (anon == null) {
      anon = const Uuid().v4();
      await prefs.setString(_kAnonId, anon);
    }
    _anonymousId = anon;

    // First-seen timestamp.
    final firstSeenStr = prefs.getString(_kFirstSeen);
    if (firstSeenStr != null) {
      _firstSeenAt = DateTime.tryParse(firstSeenStr);
    } else {
      _firstSeenAt = DateTime.now().toUtc();
      await prefs.setString(_kFirstSeen, _firstSeenAt!.toIso8601String());
    }

    _userId = initialUserId;

    // Stay in sync with Supabase auth across the app's lifetime. This catches
    // the cold-start case where the session is restored *after* Analytics.init
    // returns, and any sign-in / sign-out / token-refresh that occurs later.
    _authSub?.cancel();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      final newId = event.session?.user.id;
      if (event.event == AuthChangeEvent.signedOut) {
        _userId = null;
      } else if (newId != null && newId != _userId) {
        _userId = newId;
      }
    });

    await _resolveDeviceContext();
    await _queue.load();

    // Lifecycle observer for app_foregrounded/backgrounded + session timing.
    WidgetsBinding.instance.addObserver(this);

    // Start the very first session and emit app_opened.
    final session = _sessions.startIfNeeded();
    await _upsertSession(session, isStart: true);

    track(Events.sessionStart, {'session_id': session.id});
    track(Events.appOpened, {'cold_start': true});

    // Periodic flush.
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(_flushEvery, (_) => unawaited(flush()));

    // Best-effort initial flush in case the queue had carry-over from a kill.
    unawaited(flush());
  }

  /// Tag subsequent events with an authenticated user_id. Call after sign-in.
  void identify(String userId) {
    _userId = userId;
  }

  /// On logout: end current session, regenerate anonymous_id (so a shared
  /// device's next user is not conflated with the previous one). Future events
  /// are anonymous until the next [identify].
  Future<void> reset() async {
    _sessions.endNow(reason: 'logout');
    final s = _sessions.current;
    if (s != null) await _upsertSession(s, isStart: false);
    track(Events.sessionEnd, {
      if (s != null) 'session_id': s.id,
      if (s != null) 'duration_seconds_bucket': _bucketSeconds(s.duration.inSeconds),
      'reason': 'logout',
    });
    track(Events.logout, {});
    await flush();

    _userId = null;

    final prefs = await SharedPreferences.getInstance();
    final newAnon = const Uuid().v4();
    await prefs.setString(_kAnonId, newAnon);
    _anonymousId = newAnon;
  }

  /// Persist the user's opt-out preference. While opted out, all track() calls
  /// are no-ops and the queue is cleared.
  Future<void> optOut(bool value) async {
    _optedOut = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOptOut, value);
    if (value) await _queue.clear();
  }

  bool get isOptedOut => _optedOut;
  String? get anonymousId => _anonymousId;
  String? get userId => _userId;

  /// Set by AnalyticsNavigatorObserver on every named-route navigation, so
  /// every subsequent event is tagged with the screen the user was on. Useful
  /// for questions like "what screen was open when this booking_failed fired?"
  void setCurrentScreen(String? screenName) {
    _currentScreen = screenName;
  }

  /// Track an event. Drops it if not registered or if required props missing.
  void track(String eventName, [Map<String, dynamic> properties = const {}]) {
    if (!_initialized || _optedOut) return;

    final cleaned = AnalyticsEventCatalog.validateAndSanitize(
      eventName,
      Map<String, dynamic>.from(properties),
      warnInDebug: kDebugMode,
    );
    if (cleaned == null) return;

    final schema = AnalyticsEventCatalog.schemaFor(eventName)!;
    final session = _sessions.current;
    final now = DateTime.now().toUtc();

    final payload = <String, dynamic>{
      'event_id'    : const Uuid().v4(),
      'occurred_at' : now.toIso8601String(),
      'event_name'  : eventName,
      'category'    : schema.category,
      'user_id'     : _userId,
      'anonymous_id': _anonymousId,
      'session_id'  : session?.id,
      'app_version' : _appVersion != null && _appBuild != null
          ? '$_appVersion+$_appBuild'
          : _appVersion,
      'platform'    : _platform,
      'os_version'  : _osVersion,
      'device_model': _deviceModel,
      'locale'      : _locale,
      'network_type': 'unknown', // resolved best-effort if needed; cheap to skip
      'screen'      : _currentScreen,
      'properties'  : cleaned,
    };

    _queue.add(payload);
    _sessions.incrementEvent();

    if (eventName == Events.screenViewed) _sessions.incrementScreen();

    if (_queue.length >= _flushSizeTrigger) unawaited(flush());
  }

  /// Force a flush now (used on app-background, on logout, on app shutdown).
  Future<void> flush() async {
    if (!_initialized || _optedOut || _flushing) return;
    if (_queue.length == 0) return;
    _flushing = true;
    try {
      while (_queue.length > 0) {
        final batch = _queue.peek(_maxBatchSize);
        if (batch.isEmpty) break;
        try {
          await _supabase
              .rpc('rpc_track_events_batch', params: {'p_events': batch})
              .timeout(const Duration(seconds: 12));
          // Server silently skips malformed rows; we accept the batch as
          // consumed once the RPC returned without error.
          _queue.acknowledge(batch.length);
        } catch (e) {
          // Network or RPC error — keep events queued, retry next flush.
          if (kDebugMode) debugPrint('[Analytics] flush failed: $e');
          break;
        }
      }
    } finally {
      _flushing = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Lifecycle (WidgetsBindingObserver)
  // ---------------------------------------------------------------------------
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_initialized) return;
    if (state == AppLifecycleState.resumed) {
      final wasInactive = _sessions.current?.endedAt != null;
      _sessions.onForeground();
      track(Events.appForegrounded, {});
      if (wasInactive) {
        // Timeout produced a new session; emit session_start for it.
        final s = _sessions.current;
        if (s != null) {
          track(Events.sessionStart, {'session_id': s.id});
          unawaited(_upsertSession(s, isStart: true));
        }
      }
    } else if (state == AppLifecycleState.paused) {
      final s = _sessions.current;
      _sessions.onBackground();
      track(Events.appBackgrounded, {
        if (s != null)
          'foreground_duration_seconds_bucket':
              _bucketSeconds(s.duration.inSeconds),
      });
      if (s != null) {
        track(Events.sessionEnd, {
          'session_id': s.id,
          'duration_seconds_bucket': _bucketSeconds(s.duration.inSeconds),
          'reason': 'background',
        });
        unawaited(_upsertSession(s, isStart: false));
      }
      unawaited(flush());
    }
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------
  Future<void> _resolveDeviceContext() async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      _appVersion = pkg.version;
      _appBuild   = pkg.buildNumber;
    } catch (_) {/* leave nulls */}
    try {
      _locale = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    } catch (_) {}
    try {
      _timezone = DateTime.now().timeZoneName;
    } catch (_) {}
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final ios = await info.iosInfo;
        _platform    = 'ios';
        _osVersion   = ios.systemVersion;
        _deviceModel = ios.utsname.machine;
      } else if (Platform.isAndroid) {
        final and = await info.androidInfo;
        _platform    = 'android';
        _osVersion   = and.version.release;
        _deviceModel = '${and.manufacturer} ${and.model}';
      } else {
        _platform = 'other';
      }
    } catch (_) {/* device_info may fail on unusual platforms */}
  }

  Future<void> _upsertSession(AnalyticsSession session,
      {required bool isStart}) async {
    if (_optedOut) return;
    try {
      await _supabase.rpc('rpc_track_session', params: {
        'p_payload': {
          'session_id'  : session.id,
          'anonymous_id': _anonymousId,
          'user_id'     : _userId,
          'started_at'  : session.startedAt.toIso8601String(),
          'ended_at'    : session.endedAt?.toIso8601String(),
          'duration_ms' : session.endedAt == null
              ? null
              : session.endedAt!.difference(session.startedAt).inMilliseconds,
          'event_count' : session.eventCount,
          'screen_count': session.screenCount,
          'app_version' : _appVersion,
          'platform'    : _platform,
          'network_type': 'unknown',
          'ended_reason': session.endedReason,
          'first_seen_at': _firstSeenAt?.toIso8601String(),
          'os_version'  : _osVersion,
          'device_model': _deviceModel,
          'app_build'   : _appBuild,
          'locale'      : _locale,
          'timezone'    : _timezone,
        }
      }).timeout(const Duration(seconds: 8));
    } catch (e) {
      if (kDebugMode) debugPrint('[Analytics] session upsert failed: $e');
    }
  }

  /// Coarse buckets for time durations (in seconds). Privacy-preserving and
  /// makes "how long did users stay" much easier to query.
  static String _bucketSeconds(int s) {
    if (s < 5)    return '0-5';
    if (s < 15)   return '5-15';
    if (s < 30)   return '15-30';
    if (s < 60)   return '30-60';
    if (s < 180)  return '1-3m';
    if (s < 600)  return '3-10m';
    if (s < 1800) return '10-30m';
    if (s < 3600) return '30-60m';
    return '60m+';
  }
}

