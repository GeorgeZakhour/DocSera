import 'package:flutter/material.dart';

class ChatScrollHelper {
  static bool isAtBottom(ScrollController controller) {
    if (!controller.hasClients) return false;
    return controller.position.pixels >=
        controller.position.maxScrollExtent - 50;
  }

  static void jumpToBottom(ScrollController controller) {
    if (!controller.hasClients) return;
    controller.jumpTo(controller.position.maxScrollExtent);
  }

  static void animateToBottom(ScrollController controller) {
    if (!controller.hasClients) return;
    controller.animateTo(
      controller.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }
}
