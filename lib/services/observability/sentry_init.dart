import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// DSN and test flag are loaded from `dart_defines/sentry.json` at build time
/// (see CLAUDE.md / README for how to wire it into Xcode and Android Studio).
///
/// If `SENTRY_DSN` is empty, Sentry is fully disabled (no-op). Safe to ship.
const String _sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

/// Pipeline test flag. When set to `1`, the app sends a captured error to
/// Sentry on startup so you can confirm the dashboard is receiving events.
const String _sentryTest = String.fromEnvironment('SENTRY_TEST', defaultValue: '');

class SentryInit {
  static bool get enabled => _sentryDsn.isNotEmpty;

  /// Wrap your app entrypoint. Crashes during runApp are captured.
  static Future<void> run(Future<void> Function() appRunner) async {
    if (!enabled) {
      await appRunner();
      return;
    }
    await SentryFlutter.init(
      (options) {
        options.dsn = _sentryDsn;
        options.environment = kReleaseMode
            ? 'production'
            : kProfileMode
                ? 'staging'
                : 'debug';
        // We never want personally identifiable info from devices.
        options.sendDefaultPii = false;
        // Sample 100% of errors. Performance/transaction sampling kept low to limit
        // noise and quota usage; tune later if needed.
        options.tracesSampleRate = 0.1;
        options.attachScreenshot = false;   // medical app — never attach UI captures
        options.attachViewHierarchy = false;
        options.beforeSend = _scrub;
      },
      appRunner: () async {
        if (_sentryTest == '1') {
          // Fire-and-forget; we don't want to block app startup on the network call.
          unawaited(testCaptureError());
        }
        await appRunner();
      },
    );
  }

  // Strip anything that could leak patient data before the event leaves the device.
  /// Test helper — throws a synthetic error so you can confirm Sentry is
  /// receiving events. Wire this to any button temporarily to verify the
  /// pipeline end-to-end. Safe to leave in code — does nothing unless called.
  static void testCrash() {
    throw StateError('Sentry test crash — if you see this in the dashboard, it works.');
  }

  /// Same idea, but for a non-crashing reported error (the more common case).
  static Future<void> testCaptureError() async {
    try {
      throw StateError('Sentry test captured error.');
    } catch (e, st) {
      await Sentry.captureException(e, stackTrace: st);
    }
  }

  /// Exception types we drop on the floor — known-benign, self-recovering,
  /// or so noisy they crowd out real signal. Keep this list short and
  /// review periodically.
  ///
  /// `RealtimeSubscribeException(timedOut)` — the Supabase realtime client
  /// times out subscribing when the network is weak. The client retries
  /// automatically on the next emit; nothing for us to do.
  ///
  /// `List<Presence>` / `List<Map<String, dynamic>>` cast errors — known
  /// bugs in older realtime_client versions when the presence payload is
  /// empty. Cosmetic.
  static const List<String> _droppedExceptionMarkers = [
    'RealtimeSubscribeException',
    "is not a subtype of type 'List<Presence>'",
    "is not a subtype of type 'List<Map<String, dynamic>>'",
  ];

  static FutureOr<SentryEvent?> _scrub(SentryEvent event, Hint hint) {
    // Drop known-benign realtime noise BEFORE doing any PII work — no point
    // scrubbing an event we're about to discard.
    final exceptions = event.exceptions ?? const [];
    for (final ex in exceptions) {
      final blob = '${ex.type ?? ''} ${ex.value ?? ''}';
      for (final marker in _droppedExceptionMarkers) {
        if (blob.contains(marker)) {
          return null; // drop entirely
        }
      }
    }
    // Also catch the case where the exception lands as a top-level message
    // rather than an `exception` entry (e.g., reported via captureMessage).
    final msg = event.message?.formatted ?? '';
    for (final marker in _droppedExceptionMarkers) {
      if (msg.contains(marker)) {
        return null;
      }
    }

    // Drop user PII fields — we'll only keep an opaque user id elsewhere if set.
    final scrubbedUser = event.user?.copyWith(
            email: null,
            ipAddress: null,
            name: null,
            data: null,
          );

    // Sentry "breadcrumbs" record recent activity (taps, network, etc.).
    // For network breadcrumbs we strip:
    //   * request/response bodies — never sent
    //   * URL query strings — may contain phone/email/tokens (e.g. ?phone=…)
    final scrubbedBreadcrumbs = event.breadcrumbs?.map((b) {
      if (b.category == 'http') {
        final data = Map<String, dynamic>.from(b.data ?? const {});
        data.remove('request_body');
        data.remove('response_body');
        data.remove('data');
        // Strip URL query string and fragment.
        final urlAny = data['url'];
        if (urlAny is String && urlAny.isNotEmpty) {
          data['url'] = _scrubUrl(urlAny);
        }
        return b.copyWith(data: data);
      }
      // Strip query strings from any "navigation" / "ui" breadcrumb URLs too.
      final msg = b.message;
      if (msg != null && msg.contains('://') && (msg.contains('?') || msg.contains('#'))) {
        return b.copyWith(message: _scrubUrl(msg));
      }
      return b;
    }).toList();

    return event.copyWith(
      user: scrubbedUser,
      breadcrumbs: scrubbedBreadcrumbs,
      request: null, // never include request bodies
    );
  }

  /// Strips query strings and fragments from a URL. Keeps scheme://host/path,
  /// drops `?…` and `#…`. Used to prevent PII (e.g. phone in query string)
  /// from landing in breadcrumbs or events.
  static String _scrubUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
        path: uri.path,
      ).toString();
    } catch (_) {
      // Not a parseable URL — strip everything from the first '?' or '#'.
      final q = url.indexOf(RegExp(r'[?#]'));
      return q >= 0 ? url.substring(0, q) : url;
    }
  }
}
