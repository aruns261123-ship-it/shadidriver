import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/shadi_imagery.dart';
import '../../../../core/theme/shadi_tokens.dart';

/// Popular-category tile from the reference (PAGE 02 · Customer Home): a
/// photographic card (105×118, radius 13) with the category scrim carrying
/// the Playfair category name and a small caption.
///
/// Images rotate through the bundled reference photography (the design's
/// hero/street photos); the composition (scrim, type, size) is exact.
class PopularCategoryCard extends StatelessWidget {
  final String title;
  final String caption;
  final VoidCallback onTap;

  /// Index of this tile in the rail — drives which reference photo it shows,
  /// mirroring the reference's [hero, street, hero] alternation.
  final int imageIndex;

  const PopularCategoryCard({
    super.key,
    required this.title,
    required this.caption,
    required this.onTap,
    this.imageIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final photo =
        imageIndex.isOdd ? ShadiImagery.streetAsset : ShadiImagery.heroAsset;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ShadiRadius.category),
        child: Container(
          width: 105,
          height: 118,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ShadiRadius.category),
            color: AppColors.darkBurgundy,
            image: DecorationImage(
              image: AssetImage(photo),
              fit: BoxFit.cover,
            ),
          ),
          padding: const EdgeInsets.all(10),
          child: DecoratedBox(
            // The reference's category scrim, laid over the photo.
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ShadiRadius.category),
              gradient: ShadiImagery.categoryScrim,
            ),
            child: Container(
              padding: const EdgeInsets.all(0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTypography.ceremonialFontFamily,
                        fontFamilyFallback:
                            AppTypography.ceremonialFontFallbacks,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall.copyWith(
                      fontSize: 7,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
