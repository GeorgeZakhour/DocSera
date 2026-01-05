import 'package:flutter/material.dart';

class ChatScrollHelper {
  // ✅ FIX: With reverse: true, Bottom is 0.0
  static bool isAtBottom(ScrollController controller) {
    if (!controller.hasClients) return false;
    return controller.position.pixels <= 50;
  }

  static void jumpToBottom(ScrollController controller) {
    if (!controller.hasClients) return;
    controller.jumpTo(0.0);
  }

  static void animateToBottom(ScrollController controller) {
    if (!controller.hasClients) return;
    controller.animateTo(
      0.0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }
}
