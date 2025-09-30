import 'package:flutter/material.dart';

InputDecoration themedInput(BuildContext context, String label, {Widget? suffix}) {
  final cs = Theme.of(context).colorScheme;
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: cs.surfaceContainerHighest,
    suffixIcon: suffix,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: cs.surfaceContainerHighest),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: cs.primary, width: 2),
    ),
  );
}
