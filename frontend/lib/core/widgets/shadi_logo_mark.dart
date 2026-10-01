import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// ShadiDriver crest emblem from the design system: the burgundy mark with the
/// asymmetric `50% 50% 50% 12px` corner and a champagne car glyph.
///
/// Used by the splash, the auth header and brand rows. [light] inverts it for
/// use over dark/burgundy surfaces (champagne tile, burgundy glyph), matching
/// the reference's `logo-light`.
class ShadiLogoMark extends StatelessWidget {
  final double size;
  final bool light;

  const ShadiLogoMark({super.key, this.size = 38, this.light = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: light ? AppColors.softChampagne : AppColors.primaryBurgundy,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.elliptical(999, 999),
          topRight: const Radius.elliptical(999, 999),
          bottomLeft: const Radius.elliptical(999, 999),
          bottomRight: Radius.elliptical(999, size * 12 / 38),
        ),
      ),
      child: Icon(
        Icons.directions_car_rounded,
        size: size * 20 / 38,
        color: light ? AppColors.primaryBurgundy : AppColors.softChampagne,
      ),
    );
  }
}

/// Wordmark row: the crest plus the Playfair Display "ShadiDriver" name, as in
/// the reference's `logo` / `logo-light` composition.
class ShadiWordmark extends StatelessWidget {
  final bool light;
  final double fontSize;
  final double markSize;

  const ShadiWordmark({
    super.key,
    this.light = false,
    this.fontSize = 21,
    this.markSize = 38,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShadiLogoMark(size: markSize, light: light),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            'ShadiDriver',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Playfair Display',
              fontFamilyFallback: const ['Georgia', 'serif'],
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: light ? Colors.white : AppColors.primaryBurgundy,
            ),
          ),
        ),
      ],
    );
  }
}
