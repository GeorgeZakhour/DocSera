// =============================================================================
// Analytics session tracker.
// =============================================================================
// A "session" is a continuous use of the app. It begins when:
//   * the app cold-starts, or
//   * the app returns to foreground after >= [_sessionTimeout] in background.
//
// It ends when the app goes to background. We don't try to detect kills
// precisely; the next session_start will simply roll forward.
//
// Session metadata is upserted to the server at start AND at end (so we have
// a duration). The server's UPSERT logic keeps the latest values.
// =============================================================================

import 'package:uuid/uuid.dart';

class AnalyticsSession {
  final String id;
  final DateTime startedAt;
  DateTime? endedAt;
  int eventCount = 0;
  int screenCount = 0;
  String? endedReason; // 'background' / 'logout' / 'timeout'

  AnalyticsSession({required this.id, required this.startedAt});

  Duration get duration =>
      (endedAt ?? DateTime.now().toUtc()).difference(startedAt);
}

class AnalyticsSessionTracker {
  /// Background time after which the next foreground starts a NEW session.
  static const _sessionTimeout = Duration(minutes: 30);

  AnalyticsSession? _current;
  DateTime? _backgroundedAt;

  AnalyticsSession? get current => _current;
  bool get hasActiveSession => _current != null && _current!.endedAt == null;

  /// Start a new session if there isn't one. Returns the session id.
  AnalyticsSession startIfNeeded() {
    if (hasActiveSession) return _current!;
    final s = AnalyticsSession(
      id: const Uuid().v4(),
      startedAt: DateTime.now().toUtc(),
    );
    _current = s;
    _backgroundedAt = null;
    return s;
  }

  /// Called from the app-lifecycle observer.
  void onForeground() {
    final bg = _backgroundedAt;
    if (bg != null) {
      final awayFor = DateTime.now().toUtc().difference(bg);
      if (awayFor >= _sessionTimeout || _current == null) {
        // Treat the previous session as ended (timeout) and start a new one.
        if (_current != null && _current!.endedAt == null) {
          _current!.endedAt = bg;
          _current!.endedReason = 'timeout';
        }
        _current = null;
        startIfNeeded();
      }
    }
    _backgroundedAt = null;
  }

  /// Called from the app-lifecycle observer.
  void onBackground() {
    _backgroundedAt = DateTime.now().toUtc();
    final s = _current;
    if (s != null && s.endedAt == null) {
      s.endedAt = _backgroundedAt;
      s.endedReason = 'background';
    }
  }

  /// Force-end the current session (e.g., on logout).
  void endNow({String reason = 'logout'}) {
    final s = _current;
    if (s != null && s.endedAt == null) {
      s.endedAt = DateTime.now().toUtc();
      s.endedReason = reason;
    }
  }

  void incrementEvent() {
    final s = _current;
    if (s != null) s.eventCount++;
  }

  void incrementScreen() {
    final s = _current;
    if (s != null) s.screenCount++;
  }
}
