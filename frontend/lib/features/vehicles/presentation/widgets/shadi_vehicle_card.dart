import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/shadi_quantity_stepper.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/shadi_card.dart';
import '../../../../core/widgets/shadi_verification_badge.dart';
import '../../../home/presentation/view_models/vehicle_card_view_model.dart';

/// Vehicle result card used by the home carousel and the search results list.
///
/// Layout contract: every text run is either [Flexible]/[Expanded] or bounded
/// and ellipsized, so real backend values (long model names, UUID ids, long
/// billing units, increased system text scale) can never produce a
/// `RenderFlex overflow`. Verified by
/// `test/features/vehicles/vehicle_card_responsive_test.dart`.
class ShadiVehicleCard extends StatelessWidget {
  final VehicleCardViewModel viewModel;
  final VoidCallback onTap;

  /// Optional ADD-TO-SELECTION affordance. When [onAddToSelection] is given,
  /// the card renders a secondary selection control under the price row so a
  /// visitor can compose a multi-vehicle booking selection directly from any
  /// list. Works WITHOUT authentication (guest-first entry) — the selection
  /// lives in an app-level guest model, not in widget state.
  final VoidCallback? onAddToSelection;

  /// True when this vehicle is already part of the current selection.
  final bool isSelected;

  /// How many units of this vehicle type the visitor has selected.
  ///
  /// Drives the `− n +` stepper: at 1 the `−` removes the line entirely, so a
  /// vehicle is always deselectable from the very card it was added on.
  final int selectedQuantity;

  /// Called with the ABSOLUTE new quantity when the visitor taps `−`/`+`.
  /// A value of 0 means "remove this line".
  final ValueChanged<int>? onQuantityChanged;

  /// Explicit removal, offered next to the stepper so taking a car out never
  /// demands arithmetic.
  final VoidCallback? onRemoveSelection;

  const ShadiVehicleCard({
    super.key,
    required this.viewModel,
    required this.onTap,
    this.onAddToSelection,
    this.isSelected = false,
    this.selectedQuantity = 0,
    this.onQuantityChanged,
    this.onRemoveSelection,
  });

  /// Selection is true when EITHER the caller's flag or a positive quantity
  /// says so — the single derived truth this card renders. Never a local bool.
  bool get _isSelected => isSelected || selectedQuantity > 0;

  @override
  Widget build(BuildContext context) {
    return ShadiCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vehicle Image Placeholder — heroes into the details gallery.
          Hero(
            tag: 'vehicle-image-${viewModel.id}',
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.secondarySurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Icon(
                Icons.directions_car_rounded,
                size: 64,
                color: AppColors.borderLight,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // -------------------------------------------------- title
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        viewModel.title,
                        style: AppTypography.titleLarge.copyWith(
                          color: AppColors.primaryBurgundy,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (viewModel.isVerifiedVehicle) ...[
                      const SizedBox(width: 8),
                      const Flexible(
                        child: ShadiVerificationBadge(
                          label: 'VERIFIED',
                          isCompact: false,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  viewModel.subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (viewModel.isVerifiedVehicle) ...[
                  const SizedBox(height: 6),
                  // Customer-facing trust statement. Deliberately NOT a link
                  // to a chauffeur profile: identity stays internal.
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: AppColors.verifiedEmerald,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Vehicle & chauffeur verified by ShadiDriver',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.verifiedEmerald,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),

                // ------------------------------------- rating + distance
                // Two flexible groups: the rating block and the distance chip
                // each give way instead of forcing a horizontal overflow.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: AppColors.champagneGold,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            viewModel.ratingText,
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textPrimaryLight,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              viewModel.reviewCountText,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textTertiaryLight,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (viewModel.distanceText.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              color: AppColors.textTertiaryLight,
                              size: 14,
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                viewModel.distanceText,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textTertiaryLight,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.borderLight),
                const SizedBox(height: 8),

                // -------------------------------------- price + action
                // The price is full width and the action sits on its own row.
                // Nothing competes for horizontal space, so a long billing
                // unit or a large system text scale cannot push the row past
                // the card edge (the old side-by-side row overflowed).
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Price',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textTertiaryLight,
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: viewModel.priceText,
                            style: AppTypography.titleMedium.copyWith(
                              color: AppColors.primaryBurgundy,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text: ' ${viewModel.priceUnit}',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (onAddToSelection != null) ...[
                      const SizedBox(height: 10),
                      // Guest-first multi-vehicle selection: composes a booking
                      // selection without ever demanding an account. A SELECTED
                      // card shows its quantity with −/+, so the same vehicle
                      // can be removed right here — no detour required.
                      if (_isSelected)
                        _SelectedVehicleControl(
                          quantity: selectedQuantity > 0 ? selectedQuantity : 1,
                          onDecrement: onQuantityChanged == null
                              ? null
                              : () => onQuantityChanged!(selectedQuantity - 1),
                          onIncrement: onQuantityChanged == null
                              ? null
                              : () => onQuantityChanged!(selectedQuantity + 1),
                          onRemove: onRemoveSelection,
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: onAddToSelection,
                            icon: const Icon(
                              Icons.add_circle_outline_rounded,
                              size: 18,
                              color: AppColors.primaryBurgundy,
                            ),
                            label: Text(
                              'Add to Selection',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.primaryBurgundy,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: AppColors.primaryBurgundy,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 12),
                    // The whole card is tappable; this is its affordance.
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBurgundy,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'View Details',
                          style: AppTypography.labelSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The SELECTED state of a vehicle card: an explicit "Selected" mark, a
/// `− n +` quantity stepper (quantity is a real line quantity, not a bool),
/// and an explicit Remove. Every control is a [Wrap] child, so a large system
/// text scale wraps onto a second line instead of overflowing.
class _SelectedVehicleControl extends StatelessWidget {
  final int quantity;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final VoidCallback? onRemove;

  const _SelectedVehicleControl({
    required this.quantity,
    this.onDecrement,
    this.onIncrement,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.verifiedEmerald.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.verifiedEmerald.withValues(alpha: 0.45),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: AppColors.verifiedEmerald,
              ),
              const SizedBox(width: 6),
              Text(
                'Selected',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.verifiedEmerald,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          // Only shown when the owner can actually change the quantity — a
          // stepper with dead buttons would read as a broken control.
          if (onDecrement != null || onIncrement != null)
            ShadiQuantityStepper(
              quantity: quantity,
              onDecrement: onDecrement,
              onIncrement: onIncrement,
            ),
          if (onRemove != null)
            TextButton(
              onPressed: onRemove,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AppColors.primaryBurgundy,
              ),
              child: Text(
                'Remove',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primaryBurgundy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
