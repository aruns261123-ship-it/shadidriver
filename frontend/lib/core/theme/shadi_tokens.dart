import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Reference design tokens (Figma "ShadiDriver UI/UX Design System", v1.0).
///
/// Every visual constant the reference specifies — palette extensions,
/// spacing, radii, elevation, icon sizing — lives here so screens never
/// hardcode reference values independently. [AppColors] and [AppTypography]
/// remain the public entry points; this file adds the exact reference values
/// around them.
abstract final class ShadiColors {
  // Core brand (already canonical in [AppColors]).
  static const Color burgundy = AppColors.primaryBurgundy; // #58111A
  static const Color burgundyDark = AppColors.darkBurgundy; // #3B0910
  static const Color gold = AppColors.champagneGold; // #D4AF37
  static const Color warmGold = AppColors.warmGold; // #C59B27
  static const Color champagne = AppColors.softChampagne; // #F5E6BE
  static const Color ivory = AppColors.ivory; // #FDFBF7

  // Reference palette extensions.
  static const Color paper = Color(0xFFF7F3EC);
  static const Color ink = Color(0xFF211D1B);
  static const Color muted = Color(0xFF746C67);
  static const Color line = Color(0xFFE7DFD5);
  static const Color green = AppColors.verifiedEmerald; // #1E7E34
  static const Color greenSoft = Color(0xFFE7F3E9);
  static const Color saffron = AppColors.urgentSaffron; // #E65100
  static const Color warningSoft = Color(0xFFFFF1DF);
  static const Color danger = Color(0xFFB42318);
  static const Color dangerSoft = Color(0xFFFCE9E7);
  static const Color neutralBadgeBg = Color(0xFFEEEAE5);
  static const Color neutralBadgeFg = Color(0xFF655F5B);
  static const Color segmentedTrack = Color(0xFFEEEAE5);

  // Dark-tint hairlines on burgundy surfaces (sidebar dividers, rate card).
  static const Color onDarkHairline = Color(0x1FFFFFFF);
  // Muted cool text on the burgundy-dark sidebar.
  static const Color sidebarMuted = Color(0xFFCBBABD);

  /// Photo scrims, exactly as the reference layers them over imagery.
  static const LinearGradient heroScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x0D190810), Color(0xD1190810)],
  );
  static const LinearGradient categoryScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x0023090D), Color(0xBF23090D)],
  );
}

/// Reference spacing (px at 390dp; used 1:1 as logical pixels).
abstract final class ShadiSpacing {
  static const double screenH = 17; // mobile-content horizontal
  static const double screenTop = 22; // mobile-content top
  static const double sectionGap = 23; // between rails
  static const double cardPadding = 18; // vehicle-content
  static const double cardPaddingCompact = 12;
  static const double panelPadding = 18; // booking panel
  static const double panelMarginH = 14;
  static const double hairline = 1;
}

/// Reference corner radii.
abstract final class ShadiRadius {
  static const double segment = 7;
  static const double badgePill = 20;
  static const double chip = 20;
  static const double controlSm = 9;
  static const double stepper = 12;
  static const double field = 13;
  static const double card = 18;
  static const double panel = 18;
  static const double category = 13;
  static const double fleetCard = 13;
  static const double adminCard = 15;
  static const double kpiTile = 10;
  static const double roundButton = 999;
}

/// Reference shadows.
abstract final class ShadiElevation {
  /// `0 8px 24px rgba(59,9,16,.08)` — cards, panels.
  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x143B0910), blurRadius: 24, offset: Offset(0, 8)),
  ];

  /// `0 18px 55px rgba(59,9,16,.09)` — hero overlays, floating cards.
  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x173B0910), blurRadius: 55, offset: Offset(0, 18)),
  ];

  /// Primary button glow `0 7px 16px rgba(88,17,26,.17)`.
  static const List<BoxShadow> primaryGlow = [
    BoxShadow(color: Color(0x2B58111A), blurRadius: 16, offset: Offset(0, 7)),
  ];

  /// Active segmented shadow `0 2px 7px rgba(0,0,0,.06)`.
  static const List<BoxShadow> segment = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 7, offset: Offset(0, 2)),
  ];

  /// Round-button shadow `0 4px 13px rgba(0,0,0,.08)`.
  static const List<BoxShadow> roundButton = [
    BoxShadow(color: Color(0x14000000), blurRadius: 13, offset: Offset(0, 4)),
  ];
}

/// Reference icon sizing (24-grid outline family, stroke ≈1.8).
abstract final class ShadiIconSize {
  static const double nav = 22;
  static const double field = 18;
  static const double badge = 13;
  static const double trustLine = 15;
  static const double specGrid = 18;
  static const double roundButton = 20;
  static const double inline = 15;
}
