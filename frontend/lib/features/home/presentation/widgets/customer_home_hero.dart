import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/shadi_imagery.dart';
import '../../../../core/widgets/shadi_round_action_button.dart';
import '../../../../core/widgets/shadi_logo_mark.dart';

/// The reference customer-home hero (PAGE 02 · Customer Home): a large photo
/// area under a dark scrim, the light wordmark + notification button on top,
/// and the editorial heading "Where do you want to go?" anchored to the bottom.
///
/// Photography is a placeholder treatment for now: until real hero imagery is
/// published, the burgundy wash stands in so the composition (scrim, copy,
/// appbar) still reads exactly as designed.
class CustomerHomeHero extends StatelessWidget {
  final int unreadCount;
  final VoidCallback? onNotifications;

  const CustomerHomeHero({
    super.key,
    required this.unreadCount,
    this.onNotifications,
  });

  static const TextStyle _heroHeading = TextStyle(
    fontFamily: AppTypography.ceremonialFontFamily,
    fontFamilyFallback: AppTypography.ceremonialFontFallbacks,
    fontSize: 34,
    height: 1.05,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 305,
      width: double.infinity,
      color: AppColors.darkBurgundy,
      child: Stack(
        children: [
          // The reference's premium vehicle photography, exactly as the
          // design specifies for the hero.
          const Positioned.fill(
            child: Image(
              image: AssetImage(ShadiImagery.heroAsset),
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          // The scrim the reference layers over the photo
          // (rgba(25,8,10,.05) → rgba(25,8,10,.82)) so copy contrast matches
          // the design.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: ShadiImagery.heroScrim),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child:                Row(
                  children: [
                    // Bounded so a large text scale can never push the row
                    // past the hero edge (overflowed 6.9px at 360dp / 1.3x).
                    const Expanded(
                      child: ShadiWordmark(
                        light: true,
                        fontSize: 17,
                        markSize: 32,
                      ),
                    ),
                    _NotificationButton(
                      unreadCount: unreadCount,
                      onTap: onNotifications,
                    ),
                  ],
                ),
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PREMIUM CHAUFFEUR SERVICE',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.softChampagne,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                    fontSize: 8,
                  ),
                ),
                const SizedBox(height: 8),
                // Editorial heading with the italic gold emphasis from the
                // reference (`em` → gold-warm italic).
                Text.rich(
                  TextSpan(
                    text: 'Where do you\n',
                    children: [
                      TextSpan(
                        text: 'want to go?',
                        style: TextStyle(
                          color: AppColors.warmGold,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  style: _heroHeading,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  final int unreadCount;
  final VoidCallback? onTap;

  const _NotificationButton({required this.unreadCount, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ShadiRoundActionButton(
          Icons.notifications_none_rounded,
          translucent: true,
          onTap: onTap,
          tooltip: 'Notifications',
        ),
        if (unreadCount > 0)
          Positioned(
            right: -1,
            top: -1,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: AppColors.urgentSaffron,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$unreadCount',
                textAlign: TextAlign.center,
                style: AppTypography.labelSmall.copyWith(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
