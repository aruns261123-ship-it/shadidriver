import 'package:flutter/material.dart';

/// Centralized spacing scale for ShadiDriver.
///
/// Keeps the 4/8pt rhythm consistent across screens: use the named tokens
/// instead of ad-hoc numeric paddings so spacing stays harmonious.
abstract final class AppSpacing {
  // Core scale
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double section = 32;
  static const double page = 40;

  // Semantic aliases
  static const EdgeInsets screenPadding = EdgeInsets.all(xl);
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);
  static const EdgeInsets listGap = EdgeInsets.only(bottom: lg);
}
