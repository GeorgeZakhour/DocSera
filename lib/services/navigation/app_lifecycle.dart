import 'dart:async';
import 'package:flutter/foundation.dart';

class AppLifecycle {
  // Global flag to track if the main app screen is mounted
  static final ValueNotifier<bool> isAppReady = ValueNotifier<bool>(false);

  /// Helper to wait until the app is ready before performing navigation
  static Future<void> waitForAppReady() async {
    if (isAppReady.value) return;

    final completer = Completer<void>();
    
    void listener() {
      if (isAppReady.value) {
        if (!completer.isCompleted) completer.complete();
        isAppReady.removeListener(listener);
      }
    }

    isAppReady.addListener(listener);
    return completer.future;
  }
}
