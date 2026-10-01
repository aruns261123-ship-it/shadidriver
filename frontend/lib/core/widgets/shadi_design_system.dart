import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Rounded icon tile used across the reference system: champagne tile with a
/// burgundy glyph (queue icons, KPI icons, spec grid tiles). [background] and
/// [iconColor] may be overridden for the soft-green / soft-red variants.
class ShadiIconTile extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? background;
  final Color? iconColor;
  final double iconSize;

  const ShadiIconTile(
    this.icon, {
    super.key,
    this.size = 34,
    this.background,
    this.iconColor,
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? AppColors.softChampagne,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(
        icon,
        size: iconSize,
        color: iconColor ?? AppColors.primaryBurgundy,
      ),
    );
  }
}

/// Section title row from the reference: an optional small-caps gold eyebrow,
/// a Playfair Display heading, and an optional trailing action link.
class ShadiSectionTitle extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final double headingSize;

  const ShadiSectionTitle({
    super.key,
    this.eyebrow,
    required this.title,
    this.action,
    this.onAction,
    this.headingSize = 27,
  });

  @override
  Widget build(BuildContext context) {
    final heading = Text(
      title,
      style: TextStyle(
        fontFamily: AppTypography.ceremonialFontFamily,
        fontFamilyFallback: AppTypography.ceremonialFontFallbacks,
        fontSize: headingSize,
        fontWeight: FontWeight.w600,
        height: 1.15,
        color: AppColors.darkBurgundy,
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow!.toUpperCase(),
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primaryBurgundy,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 5),
              ],
              heading,
            ],
          ),
        ),
        if (action != null)
          TextButton.icon(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryBurgundy,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const SizedBox.shrink(),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  action!,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primaryBurgundy,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.arrow_forward_rounded, size: 15),
              ],
            ),
          ),
      ],
    );
  }
}

/// The trust sentence from the reference: a green shield plus the exact
/// promise "Vehicle and chauffeur verified by ShadiDriver".
class ShadiTrustLine extends StatelessWidget {
  final double fontSize;

  const ShadiTrustLine({super.key, this.fontSize = 9});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.shield_outlined,
          size: 16,
          color: AppColors.verifiedEmerald,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            'Vehicle and chauffeur verified by ShadiDriver',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.verifiedEmerald,
              fontWeight: FontWeight.w600,
              fontSize: fontSize,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
