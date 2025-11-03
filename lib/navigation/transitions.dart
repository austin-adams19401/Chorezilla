import 'package:flutter/material.dart';

Route<T> fadeThrough<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, anim, secAnim, child) {
      final fade = Tween(begin: 0.0, end: 1.0).animate(anim);
      final scale = Tween(begin: 0.98, end: 1.0).animate(anim);
      return FadeTransition(opacity: fade, child: ScaleTransition(scale: scale, child: child));
    },
  );
}
