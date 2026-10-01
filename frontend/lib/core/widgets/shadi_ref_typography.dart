import 'package:flutter/material.dart';

import '../theme/app_typography.dart';

/// The reference type scale — exact sizes, weights, and tracking from the
/// Figma design system. Editorial headings are Playfair Display w600; UI
/// text is Plus Jakarta Sans. Use these styles wherever the reference
/// specifies a measurement; do not approximate with the Material scale.
abstract final class ShadiRefType {
  // ----------------------------------------------------------- editorial
  /// `.hero-copy>div` — 34px/1.05 Playfair w600 (hero, driver header).
  static const TextStyle display34 = TextStyle(
    fontFamily: AppTypography.ceremonialFontFamily,
    fontFamilyFallback: AppTypography.ceremonialFontFallbacks,
    fontSize: 34,
    height: 1.05,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.6,
  );

  /// `.form-title` — 31px/1.04 Playfair w600.
  static const TextStyle display31 = TextStyle(
    fontFamily: AppTypography.ceremonialFontFamily,
    fontFamilyFallback: AppTypography.ceremonialFontFallbacks,
    fontSize: 31,
    height: 1.04,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
  );

  /// `.detail-title>div` — 29px Playfair w600 (vehicle detail title).
  static const TextStyle display29 = TextStyle(
    fontFamily: AppTypography.ceremonialFontFamily,
    fontFamilyFallback: AppTypography.ceremonialFontFallbacks,
    fontSize: 29,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
  );

  /// `.section-heading` — 27px Playfair (system cards), 20px in mobile
  /// content, 19–20px in ops cards.
  static const TextStyle heading27 = TextStyle(
    fontFamily: AppTypography.ceremonialFontFamily,
    fontFamilyFallback: AppTypography.ceremonialFontFallbacks,
    fontSize: 27,
    fontWeight: FontWeight.w600,
  );

  /// `.vehicle-title` — 22px Playfair w600 (vehicle card title).
  static const TextStyle heading22 = TextStyle(
    fontFamily: AppTypography.ceremonialFontFamily,
    fontFamilyFallback: AppTypography.ceremonialFontFallbacks,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  /// `.mobile-content .section-heading` — 20px Playfair w600.
  static const TextStyle heading20 = TextStyle(
    fontFamily: AppTypography.ceremonialFontFamily,
    fontFamilyFallback: AppTypography.ceremonialFontFallbacks,
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  /// `.fleet-count>b`, `.metric-pair b` — Playfair 32 / 27 numerals.
  static const TextStyle numeral32 = TextStyle(
    fontFamily: AppTypography.ceremonialFontFamily,
    fontFamilyFallback: AppTypography.ceremonialFontFallbacks,
    fontSize: 32,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle numeral27 = TextStyle(
    fontFamily: AppTypography.ceremonialFontFamily,
    fontFamilyFallback: AppTypography.ceremonialFontFallbacks,
    fontSize: 27,
    fontWeight: FontWeight.w600,
  );

  /// `.category-card b` — 15px Playfair w600.
  static const TextStyle heading15 = TextStyle(
    fontFamily: AppTypography.ceremonialFontFamily,
    fontFamilyFallback: AppTypography.ceremonialFontFallbacks,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  // ----------------------------------------------------------------- UI
  /// `.simple-appbar b` — 12px w700 route title.
  static const TextStyle ui12Bold = TextStyle(
    fontFamily: AppTypography.uiFontFamily,
    fontFamilyFallback: AppTypography.uiFontFallbacks,
    fontSize: 12, fontWeight: FontWeight.w700, height: 1.3);
  /// `.field b` — 17px strong field value.
  static const TextStyle ui17 = TextStyle(
    fontFamily: AppTypography.uiFontFamily,
    fontFamilyFallback: AppTypography.uiFontFallbacks,
    fontSize: 17, fontWeight: FontWeight.w700, height: 1.3);
  /// `.price b` — 15px strong (card fares, rate card).
  static const TextStyle ui15Strong = TextStyle(
    fontFamily: AppTypography.uiFontFamily,
    fontFamilyFallback: AppTypography.uiFontFallbacks,
    fontSize: 15, fontWeight: FontWeight.w700, height: 1.3);
  /// `.fleet-car b`, `.attention-card b`, `.results-summary` — 10px.
  static const TextStyle ui10 = TextStyle(
    fontFamily: AppTypography.uiFontFamily,
    fontFamilyFallback: AppTypography.uiFontFallbacks,
    fontSize: 10, fontWeight: FontWeight.w600, height: 1.35);
  /// `.vehicle-spec` — 10px muted.
  static const TextStyle ui10Muted = TextStyle(
    fontFamily: AppTypography.uiFontFamily,
    fontFamilyFallback: AppTypography.uiFontFallbacks,
    fontSize: 10, fontWeight: FontWeight.w400, height: 1.35);
  /// `.selection-bar b` — 11px w700.
  static const TextStyle ui11Bold = TextStyle(
    fontFamily: AppTypography.uiFontFamily,
    fontFamilyFallback: AppTypography.uiFontFallbacks,
    fontSize: 11, fontWeight: FontWeight.w700, height: 1.3);
  /// Badges: 9px w700 uppercase, tracking .04em.
  static const TextStyle ui9Caps = TextStyle(
    fontFamily: AppTypography.uiFontFamily,
    fontFamilyFallback: AppTypography.uiFontFallbacks,
    fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.36, height: 1.2);
  /// Eyebrows: 8–10px w700 uppercase with reference tracking.
  static const TextStyle eyebrow8 = TextStyle(
    fontFamily: AppTypography.uiFontFamily,
    fontFamilyFallback: AppTypography.uiFontFallbacks,
    fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1.44, height: 1.2);
  static const TextStyle eyebrow10 = TextStyle(
    fontFamily: AppTypography.uiFontFamily,
    fontFamilyFallback: AppTypography.uiFontFallbacks,
    fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.0, height: 1.2);
  /// `.vehicle-spec`-adjacent 7px captions (spec grid, category caption).
  static const TextStyle ui7 = TextStyle(
    fontFamily: AppTypography.uiFontFamily,
    fontFamilyFallback: AppTypography.uiFontFallbacks,
    fontSize: 7, fontWeight: FontWeight.w600, height: 1.3);
  /// `.attention-card span` / metric labels — 7–8px muted.
  static const TextStyle ui8 = TextStyle(
    fontFamily: AppTypography.uiFontFamily,
    fontFamilyFallback: AppTypography.uiFontFallbacks,
    fontSize: 8, fontWeight: FontWeight.w400, height: 1.3);

  /// Uppercase transform helper for labels/badges.
  static String caps(String text) => text.toUpperCase();
}
