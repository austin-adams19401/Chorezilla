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
  static final ColorScheme _darkScheme = ColorScheme.fromSeed(
    seedColor: zillaGreen,
    brightness: Brightness.dark,
  ).copyWith(
    primary: zillaGreen,
    secondary: _lighten(deepNavy, 0.18),     // still navy-family but a bit lighter for contrast
    tertiary: mint,
    surface: deepNavy,                       // matches your icon background
    inversePrimary: _lighten(zillaGreen, 0.30),
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

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: _darkScheme,
        scaffoldBackgroundColor: _darkScheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: _darkScheme.surface,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _darkScheme.primary,
            foregroundColor: deepNavy, // readable on bright green
          ),
        ),
      );
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