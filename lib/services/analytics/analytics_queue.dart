// =============================================================================
// Analytics persistent queue.
// =============================================================================
// Events are appended to an in-memory list AND mirrored to SharedPreferences
// (newline-delimited JSON) so they survive app kill. On flush, the head of the
// queue is sent in a single batch RPC; on success, the head is dropped from
// both memory and persistent storage. On failure (network / RPC error), the
// queue is preserved and retried next flush.
//
// Capped at 5,000 events to bound memory and storage usage even if the user
// stays offline for days. When the cap is exceeded, the OLDEST events are
// dropped — favoring recent activity over ancient history.
// =============================================================================

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AnalyticsQueue {
  static const _prefsKey = 'analytics_queue_v1';
  static const int _hardCap = 5000;

  final List<Map<String, dynamic>> _events = [];
  SharedPreferences? _prefs;
  bool _loaded = false;

  /// Restore any events persisted from a prior run. Call once at init.
  Future<void> load() async {
    if (_loaded) return;
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getStringList(_prefsKey);
    if (raw != null) {
      for (final line in raw) {
        try {
          final m = jsonDecode(line);
          if (m is Map<String, dynamic>) _events.add(m);
        } catch (_) {/* skip corrupt lines */}
      }
    }
    _loaded = true;
  }

  int get length => _events.length;

  void add(Map<String, dynamic> event) {
    _events.add(event);
    if (_events.length > _hardCap) {
      // Drop oldest first.
      _events.removeRange(0, _events.length - _hardCap);
    }
    _persist();
  }

  /// Take up to [max] events from the head WITHOUT removing them. Caller flushes
  /// them and then calls [acknowledge] only on success.
  List<Map<String, dynamic>> peek(int max) {
    if (_events.isEmpty) return const [];
    final take = max < _events.length ? max : _events.length;
    return List<Map<String, dynamic>>.unmodifiable(_events.sublist(0, take));
  }

  /// Remove the first [count] events (called after a successful flush).
  void acknowledge(int count) {
    if (count <= 0) return;
    final remove = count > _events.length ? _events.length : count;
    _events.removeRange(0, remove);
    _persist();
  }

  Future<void> _persist() async {
    final p = _prefs;
    if (p == null) return;
    if (_events.isEmpty) {
      await p.remove(_prefsKey);
      return;
    }
    final lines = _events.map(jsonEncode).toList(growable: false);
    await p.setStringList(_prefsKey, lines);
  }

  Future<void> clear() async {
    _events.clear();
    await _prefs?.remove(_prefsKey);
  }
}
