import 'package:flutter/material.dart';

ButtonStyle outlinedButton = OutlinedButton.styleFrom(
  backgroundColor: Colors.white,
  foregroundColor: Colors.black87,
  side: const BorderSide(color: Color(0xFFDADCE0), width: 1),
  shape: const StadiumBorder(),
  minimumSize: const Size.fromHeight(48),
  padding: const EdgeInsets.symmetric(horizontal: 16),
  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: .2),
).merge(ButtonStyle(
  overlayColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.pressed)) return Colors.black;
    if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) {
      return Colors.black;
    }
    return null;
  }),
));