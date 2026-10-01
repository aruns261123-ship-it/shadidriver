import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/shadi_imagery.dart';
import '../../../../core/theme/shadi_tokens.dart';
import '../../../../core/widgets/shadi_quantity_stepper.dart';
import '../../../../core/widgets/shadi_ref_typography.dart';
import '../../../home/presentation/view_models/vehicle_card_view_model.dart';

/// The reference vehicle listing card (PAGE 01 §06 / PAGE 02), matched 1:1:
///
/// ┌──────────────────────────┐
/// │      PHOTO (150/120)     │  heart 39px top-right · "Premium" gold badge top-left
/// ├──────────────────────────┤
/// │ Toyota Thar     ₹21.88/km│  Playfair 22 + 10px spec line · strong price
/// │ ✓ Vehicle and chauffeur  │  green trust line
/// │ ─────────────────────────│  hairline
/// │ ESTIMATED FARE    [ Add ]│  eyebrow + strong fare, burgundy 38h CTA
/// └──────────────────────────┘
///
/// Layout contract: every text run is bounded/ellipsized and every row gives
/// way via Flexible, so real backend values (long model names, wide fares,
/// large system text scale) can never produce a `RenderFlex overflow`.
///
/// Guest selection semantics are preserved EXACTLY: add → the champagne
/// "Added" state with a −n+ stepper → explicit Remove. The selection lives
/// in the app-level guest model, never in widget state.
class ShadiVehicleCard extends StatelessWidget {
  final VehicleCardViewModel viewModel;
  final VoidCallback onTap;

  /// Optional ADD-TO-SELECTION affordance. When [onAddToSelection] is given,
  /// the card renders the reference's Add control so a visitor can compose a
  /// multi-vehicle booking selection directly from any list — WITHOUT
  /// authentication (guest-first entry).
  final VoidCallback? onAddToSelection;

  /// True when this vehicle is already part of the current selection.
  final bool isSelected;

  /// How many units of this vehicle type the visitor has selected.
  final int selectedQuantity;

  /// Called with the ABSOLUTE new quantity when the visitor taps `−`/`+`.
  /// A value of 0 means "remove this line".
  final ValueChanged<int>? onQuantityChanged;

  /// Explicit removal, offered next to the stepper so taking a car out never
  /// demands arithmetic.
  final VoidCallback? onRemoveSelection;

  /// Compact variant (home "Suggested near you"): image 120px, padding 12.
  final bool compact;

  /// Favorite state + toggle, provided by the parent screen (the favorites
  /// store is account-aware and lives above the card).

  const ShadiVehicleCard({
    super.key,
    required this.viewModel,
    required this.onTap,
    this.onAddToSelection,
    this.isSelected = false,
    this.selectedQuantity = 0,
    this.onQuantityChanged,
    this.onRemoveSelection,
    this.compact = false,
    this.isFavorite = false,
    this.onToggleFavorite,
  });

  /// Selection is true when EITHER the caller's flag or a positive quantity
  /// says so — the single derived truth this card renders. Never a local bool.
  bool get _isSelected => isSelected || selectedQuantity > 0;

  /// Favorite state + toggle, provided by the parent screen.
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final pad = compact ? 12.0 : ShadiSpacing.cardPadding;
    final imageHeight = compact ? 120.0 : 150.0;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ShadiRadius.card),
        border: Border.all(color: ShadiColors.line),
        boxShadow: compact
            ? null
            : const [
                BoxShadow(
                  color: Color(0x143B0910),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ------------------------------------------------ photo header
              Hero(
                tag: 'vehicle-image-${viewModel.id}',
                child: _VehicleImage(
                  source: ShadiImagery.forVehicle(
                    viewModel.imageUrl,
                    vehicleId: viewModel.id,
                  ),
                  height: imageHeight,
                  isPremiumBadgeVisible: viewModel.isPremium,
                  isFavorite: isFavorite,
                  onFavoriteTap: onToggleFavorite,
                ),
              ),

              // ---------------------------------------------------- content
              Padding(
                padding: EdgeInsets.all(pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row: Playfair 22 title + spec line LEFT, the
                    // per-km price RIGHT (baseline-aligned).
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                viewModel.title,
                                style: ShadiRefType.heading22.copyWith(
                                  color: AppColors.darkBurgundy,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                viewModel.subtitle,
                                style: ShadiRefType.ui10Muted.copyWith(
                                  color: ShadiColors.muted,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Flexible so a wide fare at a large text scale
                        // ellipsizes instead of pushing the row past the
                        // card edge.
                        Flexible(
                          child: _PerKmPrice(
                            priceText: viewModel.priceText,
                            unit: viewModel.priceUnit,
                          ),
                        ),
                      ],
                    ),

                    // ------------------------------------------------ trust
                    if (viewModel.isVerifiedVehicle) ...[
                      SizedBox(height: compact ? 8 : 14),
                      Row(
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            size: ShadiIconSize.trustLine,
                            color: ShadiColors.green,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              'Vehicle and chauffeur verified by ShadiDriver',
                              style: ShadiRefType.ui9Caps.copyWith(
                                letterSpacing: 0,
                                textBaseline: null,
                                fontSize: 9,
                                color: ShadiColors.green,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    SizedBox(height: compact ? 9 : 13),
                    // --------------------------------- hairline + bottom row
                    Container(height: 1, color: ShadiColors.line),
                    SizedBox(height: compact ? 9 : 13),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ESTIMATED FARE'.toUpperCase(),
                                style: ShadiRefType.eyebrow8.copyWith(
                                  color: ShadiColors.muted,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                viewModel.fareEstimateText,
                                style: ShadiRefType.ui15Strong.copyWith(
                                  color: AppColors.textPrimaryLight,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Flexible so the selected control's Wrap can wrap
                        // onto a second line at a large text scale instead
                        // of overflowing (the −n+/Remove cluster grows a
                        // lot at 2x).
                        Flexible(
                          child: _CardAction(
                            isCompact: compact,
                            isSelected: _isSelected,
                            selectedQuantity:
                                selectedQuantity > 0 ? selectedQuantity : 1,
                            onAdd: onAddToSelection,
                            onQuantityChanged: onQuantityChanged,
                            onRemove: onRemoveSelection,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The photo header: cover image, 39px round heart button top-right, the
/// gold "Premium" badge top-left — exactly the reference placement.
class _VehicleImage extends StatelessWidget {
  final String source;
  final double height;
  final bool isPremiumBadgeVisible;
  final bool isFavorite;
  final VoidCallback? onFavoriteTap;

  const _VehicleImage({
    required this.source,
    required this.height,
    required this.isPremiumBadgeVisible,
    this.isFavorite = false,
    this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ShadiImagery.isAsset(source)
              ? Image.asset(source, fit: BoxFit.cover)
              : Image.network(
                  source,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Image.asset(
                    ShadiImagery.primary,
                    fit: BoxFit.cover,
                  ),
                  frameBuilder: (context, child, frame, wasSync) {
                    // Placeholder while loading: a champagne-tinted surface,
                    // never a bare gradient block.
                    if (wasSync) return child;
                    return AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      opacity: frame == null ? 0 : 1,
                      child: child,
                    );
                  },
                ),
          // Top row: badge left, heart right.
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isPremiumBadgeVisible)
                  const _GoldBadge('Premium')
                else
                  const SizedBox(width: 39, height: 26),
                _RoundIconButton(
                  icon: isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  iconColor:
                      isFavorite ? const Color(0xFFB42318) : ShadiColors.burgundy,
                  onTap: onFavoriteTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 39px round translucent button used on imagery (heart here; the same
/// geometry appears on hero/detail headers).
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;

  const _RoundIconButton({
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 39,
          height: 39,
          child: Icon(icon, size: 18, color: iconColor),
        ),
      ),
    );
  }
}

/// The gold "Premium" badge: champagne pill, burgundy-dark 9px caps text.
class _GoldBadge extends StatelessWidget {
  final String label;

  const _GoldBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ShadiColors.champagne,
        borderRadius: BorderRadius.circular(ShadiRadius.badgePill),
      ),
      child: Text(
        label.toUpperCase(),
        style: ShadiRefType.ui9Caps.copyWith(color: AppColors.darkBurgundy),
      ),
    );
  }
}

/// The right-hand per-km price: strong burgundy figure + muted "/km" unit.
class _PerKmPrice extends StatelessWidget {
  final String priceText;
  final String unit;

  const _PerKmPrice({required this.priceText, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          priceText,
          style: ShadiRefType.ui15Strong.copyWith(color: ShadiColors.burgundy),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 1),
        Text(
          unit,
          style: ShadiRefType.ui9Caps.copyWith(
            color: ShadiColors.muted,
            letterSpacing: 0,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// The card CTA: burgundy "Add" (38px min) that becomes the champagne
/// secondary "Added ✓" state with a −n+ stepper and Remove — the reference's
/// exact selected behavior, wired to the app-level guest selection.
class _CardAction extends StatelessWidget {
  final bool isCompact;
  final bool isSelected;
  final int selectedQuantity;
  final VoidCallback? onAdd;
  final ValueChanged<int>? onQuantityChanged;
  final VoidCallback? onRemove;

  const _CardAction({
    required this.isCompact,
    required this.isSelected,
    required this.selectedQuantity,
    this.onAdd,
    this.onQuantityChanged,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (isSelected && onQuantityChanged != null) {
      return _SelectedControl(
        quantity: selectedQuantity,
        onDecrement: onQuantityChanged == null
            ? null
            : () => onQuantityChanged!(selectedQuantity - 1),
        onIncrement: onQuantityChanged == null
            ? null
            : () => onQuantityChanged!(selectedQuantity + 1),
        onRemove: onRemove,
      );
    }
    if (onAdd == null) {
      // No selection affordance (e.g. a plain browse list): the reference
      // still renders a card action, so keep a stable 'Selected' marker for
      // selected lines.
      return isSelected
          ? Text(
              'Selected',
              style: ShadiRefType.ui10.copyWith(
                color: ShadiColors.green,
                fontWeight: FontWeight.w700,
              ),
            )
          : const SizedBox.shrink();
    }
    return Material(
      color: ShadiColors.burgundy,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onAdd,
        child: Container(
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          child: Text(
            'Add',
            style: ShadiRefType.ui12Bold.copyWith(
              color: Colors.white,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}

/// The SELECTED state: champagne secondary "Added ✓" affordance with the
/// −n+ quantity stepper (quantity is a real line quantity, not a bool) and
/// an explicit Remove. Every control is a [Wrap] child, so a large system
/// text scale wraps onto a second line instead of overflowing.
class _SelectedControl extends StatelessWidget {
  final int quantity;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final VoidCallback? onRemove;

  const _SelectedControl({
    required this.quantity,
    this.onDecrement,
    this.onIncrement,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ShadiColors.champagne.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 4,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_rounded,
                size: 14,
                color: ShadiColors.green,
              ),
              const SizedBox(width: 3),
              // Flexible: at a large text scale the marker yields instead of
              // pushing its run past the card edge.
              Flexible(
                child: Text(
                  'Selected',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ShadiRefType.ui10.copyWith(
                    color: ShadiColors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          ShadiQuantityStepper(
            quantity: quantity,
            onDecrement: onDecrement,
            onIncrement: onIncrement,
          ),
          if (onRemove != null)
            GestureDetector(
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Remove',
                  style: ShadiRefType.ui10.copyWith(
                    color: ShadiColors.burgundy,
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
