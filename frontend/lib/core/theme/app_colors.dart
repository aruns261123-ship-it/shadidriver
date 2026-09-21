import 'package:flutter/material.dart';

/// Centralized Design System Color Tokens for ShadiDriver.
/// Literal color hex codes must not be scattered throughout widget implementations.
abstract final class AppColors {
  // Brand Core Colors
  static const Color primaryBurgundy = Color(0xFF58111A);
  static const Color darkBurgundy = Color(0xFF3B0910);
  static const Color champagneGold = Color(0xFFD4AF37);
  static const Color warmGold = Color(0xFFC59B27);
  static const Color softChampagne = Color(0xFFF5E6BE);
  static const Color ivory = Color(0xFFFDFBF7);
  static const Color secondarySurface = Color(0xFFF5F2FB);

  // Status & Operational Colors
  static const Color verifiedEmerald = Color(0xFF1E7E34);
  static const Color urgentSaffron = Color(0xFFE65100);
  static const Color errorRed = Color(0xFFBA1A1A);

  // Neutral Scales (Light)
  static const Color textPrimaryLight = Color(0xFF1C1B1F);
  static const Color textSecondaryLight = Color(0xFF49454F);
  static const Color textTertiaryLight = Color(0xFF79747E);
  static const Color borderLight = Color(0xFFE6E1E5);
  static const Color cardSurfaceLight = Color(0xFFFFFFFF);
  static const Color backgroundLight = ivory;

  // Neutral Scales (Dark)
  static const Color textPrimaryDark = Color(0xFFEDE0D4);
  static const Color textSecondaryDark = Color(0xFFCAC4D0);
  static const Color textTertiaryDark = Color(0xFF938F99);
  static const Color borderDark = Color(0xFF49454F);
  static const Color cardSurfaceDark = Color(0xFF241416);
  static const Color backgroundDark = Color(0xFF1B0B0D);
}
