import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/core/theme/app_colors.dart';
import 'package:shadidriver/core/theme/app_theme.dart';
import 'package:shadidriver/core/theme/app_typography.dart';

void main() {
  group('ShadiDriver Theme & Token Tests', () {
    test('Verifies documented primary and ceremonial color hex values', () {
      expect(AppColors.primaryBurgundy, equals(const Color(0xFF58111A)));
      expect(AppColors.darkBurgundy, equals(const Color(0xFF3B0910)));
      expect(AppColors.champagneGold, equals(const Color(0xFFD4AF37)));
      expect(AppColors.warmGold, equals(const Color(0xFFC59B27)));
      expect(AppColors.softChampagne, equals(const Color(0xFFF5E6BE)));
      expect(AppColors.ivory, equals(const Color(0xFFFDFBF7)));
      expect(AppColors.secondarySurface, equals(const Color(0xFFF5F2FB)));
      expect(AppColors.verifiedEmerald, equals(const Color(0xFF1E7E34)));
      expect(AppColors.urgentSaffron, equals(const Color(0xFFE65100)));
    });

    test('Verifies documented typography font families', () {
      expect(AppTypography.ceremonialFontFamily, equals('Playfair Display'));
      expect(AppTypography.uiFontFamily, equals('Plus Jakarta Sans'));
    });

    test('Light theme creates Material 3 ThemeData with correct primary', () {
      final theme = AppTheme.lightTheme;

      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.primary, equals(AppColors.primaryBurgundy));
      expect(theme.colorScheme.secondary, equals(AppColors.champagneGold));
      expect(theme.scaffoldBackgroundColor, equals(AppColors.ivory));
    });

    test('Dark theme creates Material 3 ThemeData with dark brightness', () {
      final theme = AppTheme.darkTheme;

      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, equals(Brightness.dark));
      expect(theme.colorScheme.primary, equals(AppColors.champagneGold));
    });
  });
}
