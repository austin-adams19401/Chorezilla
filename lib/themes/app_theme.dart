// lib/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  // Brand colors from the Chorezilla icon
  static const Color zillaGreen = Color(0xFF2ECC71);
  static const Color deepNavy  = Color(0xFF0B2545);
  static const Color white     = Color(0xFFFFFFFF);

  // Helpers to make pleasant tints/shades
  static Color _lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }
  static Color _tint(Color a, Color b, double t) =>
      Color.lerp(a, b, t) ?? a;

  // A softer mint from the primary green for tertiary accents
  static final Color mint = _lighten(zillaGreen, 0.25);

  // Light scheme (paper-like surface with a hint of green)
  static final ColorScheme _lightScheme = ColorScheme.fromSeed(
    seedColor: zillaGreen,
    brightness: Brightness.light,
  ).copyWith(
    primary: zillaGreen,
    secondary: deepNavy,
    tertiary: mint,
    surface: _tint(white, zillaGreen, 0.05), // near-white with a tiny green tint
    inversePrimary: deepNavy,                // contrasts the green nicely
  );

  // Dark scheme (navy surfaces; green pops as the brand color)
  //
  // Key usage patterns in the app that drive these choices:
  //   - AppBar + hero sections use cs.secondary as BACKGROUND → must be dark with white text
  //   - Pending card uses cs.secondary as card background
  //   - Reward tiles inside pending card use surfaceContainerHighest→surface gradient
  //   - Filter chips use secondaryContainer bg / onSecondaryContainer text
  static final ColorScheme _darkScheme = ColorScheme.fromSeed(
    seedColor: zillaGreen,
    brightness: Brightness.dark,
  ).copyWith(
    // Primary — teal CTAs for dark mode (FAB, filled buttons, active tab, text buttons)
    primary: const Color(0xFF26C6C6),
    onPrimary: deepNavy,
    primaryContainer: const Color(0xFF0D5C5C),      // teal pill/container bg
    onPrimaryContainer: const Color(0xFFB2EFEF),    // pale cyan text on teal

    // Secondary — used as AppBar bg, hero sections, pending card bg
    // Must be dark enough for white text to work on it
    secondary: const Color(0xFF1A3A60),
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFF254E7A),    // medium navy for filter chips
    onSecondaryContainer: const Color(0xFFD4E8F8),  // near-white for chip text

    // Tertiary — mint accent for badges, XP, pending chips
    tertiary: mint,
    onTertiary: deepNavy,
    tertiaryContainer: const Color(0xFF0F3D28),     // dark green container
    onTertiaryContainer: const Color(0xFF86EFAC),   // light mint text

    // Surface — scaffold and card background (deepest layer)
    surface: const Color(0xFF0D1B30),
    onSurface: Colors.white,
    onSurfaceVariant: const Color(0xFFB0C4D8),      // muted secondary text / icons

    // Surface containers — stepped lighter navies so tiles inside cards look good
    surfaceContainerLowest: const Color(0xFF0A1525),
    surfaceContainerLow:    const Color(0xFF0F2035),
    surfaceContainer:       const Color(0xFF142840),
    surfaceContainerHigh:   const Color(0xFF1A3050),
    surfaceContainerHighest: const Color(0xFF1E3860),

    // Outlines
    outline: const Color(0xFF3D5E7A),
    outlineVariant: const Color(0xFF2A4A6A),

    inversePrimary: const Color(0xFF80E8E8),
  );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: _lightScheme,
        scaffoldBackgroundColor: _lightScheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: _lightScheme.surface,
          foregroundColor: _lightScheme.secondary,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _lightScheme.primary,
            foregroundColor: Colors.white,
          ),
        ),
      );

  static ThemeData get dark {
    // Flutter's TextTheme colors are independent of colorScheme — force all
    // text white so it's legible on the deep navy surface.
    final baseTextTheme = ThemeData(useMaterial3: true, colorScheme: _darkScheme).textTheme;
    final whiteTextTheme = baseTextTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: _darkScheme,
      textTheme: whiteTextTheme,
      scaffoldBackgroundColor: _darkScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: _darkScheme.surface,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _darkScheme.primary,
          foregroundColor: deepNavy,
        ),
      ),
    );
  }
}

// primary:	
//    Your brand/CTA color	
//    Filled buttons, FAB, active slider/switch/radio, progress indicators	
//    “Do it” actions: Add Chore, Redeem, FAB “+”, selected tab/segment
// secondary:
//    A supporting accent (less loud than primary)	
//    Icons/text, outlines, Chips, secondary buttons	
//    Headings, icons on light backgrounds, filter chips, subtle accents (our Deep Navy works great here)
// tertiary:	
//    An extra accent for special meaning	
//    Badges, highlights, tertiary buttons	
//    “XP earned”, reward highlights, success badges (a mint/light-green pop)
// surface:
//    Backgrounds that content sits on	
//    Scaffold/page background, Cards, Sheets, Menus	
//    Page bg, cards, bottom sheets; pair text/icons with onSurface
// inversePrimary:	
//    Attention color on dark/colored surfaces	
//    Icons/links on dark bars, small accents on Navy areas	
//    Top bars/sections with Navy bg; small brand pops without using plain white