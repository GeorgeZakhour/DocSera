import 'package:flutter/material.dart';

// Function to return a fade transition route
Route fadePageRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const curve = Curves.easeInOut;
      var tween = Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));
      var opacityAnimation = animation.drive(tween);

      return FadeTransition(opacity: opacityAnimation, child: child);
    },
    transitionDuration: const Duration(milliseconds: 100), // Fast fade transition
  );
}
