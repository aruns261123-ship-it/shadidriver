import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Status pill from the ShadiDriver design system (PAGE 01 · STATUS).
///
/// Compact uppercase pill with an optional leading check mark. Tones map to
/// the reference palette: success → verified green, warning → urgent saffron,
/// danger → danger red, neutral → stone, gold → champagne.
class ShadiBadge extends StatelessWidget {
  final String label;
  final ShadiBadgeTone tone;
  final bool showCheck;

  const ShadiBadge(
    this.label, {
    super.key,
    this.tone = ShadiBadgeTone.neutral,
    this.showCheck = false,
  });

  /// VERIFIED / APPROVED / CONFIRMED / COMPLETED / AVAILABLE in one call.
  const ShadiBadge.success(this.label, {super.key})
      : tone = ShadiBadgeTone.success,
        showCheck = true;

  const ShadiBadge.gold(this.label, {super.key})
      : tone = ShadiBadgeTone.gold,
        showCheck = false;

  const ShadiBadge.warning(this.label, {super.key})
      : tone = ShadiBadgeTone.warning,
        showCheck = false;

  const ShadiBadge.neutral(this.label, {super.key})
      : tone = ShadiBadgeTone.neutral,
        showCheck = false;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      ShadiBadgeTone.success => (
          AppColors.verifiedEmerald.withValues(alpha: 0.12),
          AppColors.verifiedEmerald,
        ),
      ShadiBadgeTone.warning => (
          const Color(0xFFFFF1DF),
          AppColors.urgentSaffron,
        ),
      ShadiBadgeTone.danger => (
          const Color(0xFFFCE9E7),
          const Color(0xFFB42318),
        ),
      ShadiBadgeTone.neutral => (
          AppColors.secondarySurface,
          AppColors.textSecondaryLight,
        ),
      ShadiBadgeTone.gold => (
          AppColors.softChampagne,
          AppColors.darkBurgundy,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showCheck) ...[
            const Icon(
              Icons.check_rounded,
              size: 13,
              color: AppColors.verifiedEmerald,
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSmall.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum ShadiBadgeTone { success, warning, danger, neutral, gold }
