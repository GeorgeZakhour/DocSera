// =============================================================================
// Auto-screen-tracking via NavigatorObserver.
// =============================================================================
// Attach the singleton observer to MaterialApp.navigatorObservers and every
// pushed/popped named-route or settings.name will fire a `screen_viewed` event
// with screen_name + previous_screen_name. Anonymous routes (no settings.name)
// are skipped to avoid noise.
//
// Runtime gating: if Analytics is opted-out or not yet initialized, this is a
// no-op. The observer is safe to attach unconditionally.
// =============================================================================

import 'package:flutter/material.dart';
import 'analytics_event_catalog.dart';
import 'analytics_service.dart';

class AnalyticsNavigatorObserver extends NavigatorObserver {
  String? _previous;

  String? _nameOf(Route<dynamic>? route) {
    if (route == null) return null;
    final n = route.settings.name;
    if (n == null || n.isEmpty) return null;
    return n;
  }

  void _emit(String name) {
    final prev = _previous;
    _previous = name;
    // Stamp every subsequent event with the current screen.
    Analytics.instance.setCurrentScreen(name);
    Analytics.instance.track(Events.screenViewed, {
      'screen_name': name,
      if (prev != null) 'previous_screen_name': prev,
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    final name = _nameOf(route);
    if (name != null) _emit(name);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    final name = _nameOf(previousRoute);
    if (name != null) _emit(name);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    final name = _nameOf(newRoute);
    if (name != null) _emit(name);
  }
}
