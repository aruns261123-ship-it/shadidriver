import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

/// Smooth fade + gentle slide-up page transition used across platforms
/// that don't use the native Cupertino transition.
class ShadiFadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const ShadiFadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// Centralized Material 3 Theme setup for ShadiDriver.
abstract final class AppTheme {
  /// Light Theme tailored to Ivory and Champagne Gold surfaces.
  static ThemeData get lightTheme {
    final colorScheme = const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primaryBurgundy,
      onPrimary: Colors.white,
      primaryContainer: AppColors.darkBurgundy,
      onPrimaryContainer: AppColors.softChampagne,
      secondary: AppColors.champagneGold,
      onSecondary: AppColors.darkBurgundy,
      secondaryContainer: AppColors.softChampagne,
      onSecondaryContainer: AppColors.darkBurgundy,
      tertiary: AppColors.warmGold,
      onTertiary: Colors.white,
      error: AppColors.errorRed,
      onError: Colors.white,
      surface: AppColors.cardSurfaceLight,
      onSurface: AppColors.textPrimaryLight,
      surfaceContainerHighest: AppColors.secondarySurface,
      onSurfaceVariant: AppColors.textSecondaryLight,
      outline: AppColors.borderLight,
      outlineVariant: AppColors.softChampagne,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ShadiFadeSlidePageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ShadiFadeSlidePageTransitionsBuilder(),
          TargetPlatform.linux: ShadiFadeSlidePageTransitionsBuilder(),
          TargetPlatform.fuchsia: ShadiFadeSlidePageTransitionsBuilder(),
        },
      ),
      textTheme: _buildTextTheme(
        AppColors.textPrimaryLight,
        AppColors.textSecondaryLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBurgundy,
        foregroundColor: AppColors.champagneGold,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: AppTypography.ceremonialFontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.champagneGold,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardSurfaceLight,
        elevation: 1,
        shadowColor: AppColors.primaryBurgundy.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderLight),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBurgundy,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTypography.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryBurgundy,
          side: const BorderSide(color: AppColors.champagneGold, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTypography.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.champagneGold,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.errorRed),
        ),
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textSecondaryLight,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textTertiaryLight,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
        space: 24,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.darkBurgundy,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.softChampagne,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.secondarySurface,
        selectedColor: AppColors.softChampagne,
        labelStyle: AppTypography.labelLarge.copyWith(
          color: AppColors.darkBurgundy,
        ),
        side: const BorderSide(color: AppColors.borderLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primaryBurgundy,
        unselectedLabelColor: AppColors.textSecondaryLight,
        labelStyle: AppTypography.titleSmall,
        unselectedLabelStyle: AppTypography.bodyMedium,
        indicatorColor: AppColors.champagneGold,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primaryBurgundy,
        unselectedItemColor: AppColors.textTertiaryLight,
        type: BottomNavigationBarType.fixed,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  /// Dark Theme for evening events and night shift operations.
  static ThemeData get darkTheme {
    final colorScheme = const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.champagneGold,
      onPrimary: AppColors.darkBurgundy,
      primaryContainer: AppColors.primaryBurgundy,
      onPrimaryContainer: AppColors.softChampagne,
      secondary: AppColors.warmGold,
      onSecondary: Colors.black,
      error: AppColors.errorRed,
      onError: Colors.white,
      surface: AppColors.cardSurfaceDark,
      onSurface: AppColors.textPrimaryDark,
      surfaceContainerHighest: Color(0xFF2E1A1E),
      onSurfaceVariant: AppColors.textSecondaryDark,
      outline: AppColors.borderDark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      textTheme: _buildTextTheme(
        AppColors.textPrimaryDark,
        AppColors.textSecondaryDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cardSurfaceDark,
        foregroundColor: AppColors.champagneGold,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardSurfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderDark),
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme(Color primaryText, Color secondaryText) {
    return TextTheme(
      displayLarge: AppTypography.displayLarge.copyWith(color: primaryText),
      displayMedium: AppTypography.displayMedium.copyWith(color: primaryText),
      displaySmall: AppTypography.displaySmall.copyWith(color: primaryText),
      titleLarge: AppTypography.titleLarge.copyWith(color: primaryText),
      titleMedium: AppTypography.titleMedium.copyWith(color: primaryText),
      titleSmall: AppTypography.titleSmall.copyWith(color: primaryText),
      bodyLarge: AppTypography.bodyLarge.copyWith(color: primaryText),
      bodyMedium: AppTypography.bodyMedium.copyWith(color: secondaryText),
      bodySmall: AppTypography.bodySmall.copyWith(color: secondaryText),
      labelLarge: AppTypography.labelLarge.copyWith(color: primaryText),
      labelMedium: AppTypography.labelMedium.copyWith(color: secondaryText),
      labelSmall: AppTypography.labelSmall.copyWith(color: secondaryText),
    );
  }
}
