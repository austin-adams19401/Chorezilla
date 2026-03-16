import 'package:flutter/material.dart';

InputDecoration themedInput(BuildContext context, String label, {Widget? suffix, String? hint}) {
  final cs = Theme.of(context).colorScheme;
  return InputDecoration(
    labelText: label,
    hintText: hint,
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
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: cs.error, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: cs.error, width: 2),
    ),
  );
}
