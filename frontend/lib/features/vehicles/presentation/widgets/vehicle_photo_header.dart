import 'package:flutter/material.dart';
import '../../../../core/theme/shadi_imagery.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/shadi_round_action_button.dart';

/// The reference detail-photo header (PAGE 02 · Car details): a tall photo
/// area with the back and favourite round buttons on top and the `1 / 8`
/// counter chip at the bottom right.
///
/// Without real photography the area falls back to a champagne-tinted vehicle
/// glyph — the composition (height, buttons, counter) still matches.
class VehiclePhotoHeader extends StatelessWidget {
  final List<String> photoUrls;
  final String heroTag;
  final bool isFavorite;
  final VoidCallback? onBack;
  final VoidCallback? onToggleFavorite;

  const VehiclePhotoHeader({
    super.key,
    required this.photoUrls,
    required this.heroTag,
    required this.isFavorite,
    this.onBack,
    this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final photos = photoUrls
        .whereType<String>()
        .where((u) => u.trim().isNotEmpty)
        .toList(growable: false);

    return SizedBox(
      height: 300,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photos.isNotEmpty)
            PageView.builder(
              itemCount: photos.length,
              itemBuilder: (context, index) => Hero(
                tag: heroTag,
                child: Image.network(
                  photos[index],
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const _PhotoFallback(),
                ),
              ),
            )
          else
            const _PhotoFallback(),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShadiRoundActionButton(
                    Icons.arrow_back_rounded,
                    onTap: onBack ?? () => Navigator.of(context).maybePop(),
                    tooltip: 'Back',
                  ),
                  ShadiRoundActionButton(
                    isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    onTap: onToggleFavorite,
                    tooltip: isFavorite
                        ? 'Remove from favourites'
                        : 'Save to favourites',
                  ),
                ],
              ),
            ),
          ),
          if (photos.isNotEmpty)
            Positioned(
              right: 15,
              bottom: 13,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xBF1E1412),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '1 / ${photos.length}',
                  style: AppTypography.labelSmall.copyWith(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();

  @override
  Widget build(BuildContext context) {
    // No backend photo yet: the bundled reference photography stands in
    // (a placeholder icon would break the design's photographic impact).
    return Image.asset(
      ShadiImagery.primary,
      fit: BoxFit.cover,
      alignment: Alignment.center,
    );
  }
}
