import 'package:flutter/material.dart';

/// Centralized Typography Architecture for ShadiDriver.
///
/// Guidelines:
/// - Playfair Display: Ceremonial headings, display headers, milestone titles.
/// - Plus Jakarta Sans: Functional UI, body copy, form fields, numbers, labels.
///
/// Note: Font families fall back to system serif / sans-serif if local font assets are not bundled.
abstract final class AppTypography {
  static const String ceremonialFontFamily = 'Playfair Display';
  static const String uiFontFamily = 'Plus Jakarta Sans';

  static const List<String> ceremonialFontFallbacks = ['Georgia', 'serif'];
  static const List<String> uiFontFallbacks = [
    'Roboto',
    'Segoe UI',
    'sans-serif',
  ];

  // Ceremonial & Display Styles (Playfair Display)
  static const TextStyle displayLarge = TextStyle(
    fontFamily: ceremonialFontFamily,
    fontFamilyFallback: ceremonialFontFallbacks,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.25,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: ceremonialFontFamily,
    fontFamilyFallback: ceremonialFontFallbacks,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
    height: 1.3,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: ceremonialFontFamily,
    fontFamilyFallback: ceremonialFontFallbacks,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.35,
  );

  // UI & Body Styles (Plus Jakarta Sans)
  static const TextStyle titleLarge = TextStyle(
    fontFamily: uiFontFamily,
    fontFamilyFallback: uiFontFallbacks,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.4,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: uiFontFamily,
    fontFamilyFallback: uiFontFallbacks,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.4,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: uiFontFamily,
    fontFamilyFallback: uiFontFallbacks,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.4,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: uiFontFamily,
    fontFamilyFallback: uiFontFallbacks,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: uiFontFamily,
    fontFamilyFallback: uiFontFallbacks,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: uiFontFamily,
    fontFamilyFallback: uiFontFallbacks,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.5,
  );

  static const TextStyle labelLarge = TextStyle(
    fontFamily: uiFontFamily,
    fontFamilyFallback: uiFontFallbacks,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.4,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: uiFontFamily,
    fontFamilyFallback: uiFontFallbacks,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.4,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: uiFontFamily,
    fontFamilyFallback: uiFontFallbacks,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.4,
  );
}
