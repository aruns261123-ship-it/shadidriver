import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/guest_fleet_selection.dart';

/// The visitor's always-available way back into their selection.
///
/// WHY THIS LIVED SOMEWHERE INVISIBLE BEFORE: the previous banner was the last
/// row of the shell's `body` [Column]. The body slot is *inside* the content
/// area, so every nested `Scaffold` a customer screen brings with it (search,
/// vehicle details, bookings) painted its own sticky footer over the same
/// pixels — on vehicle details the selection row was pushed under the
/// "Book Now" bar and stopped looking like a global action at all. It also had
/// no elevation and expressed its call to action as plain text, so nothing
/// about it said "tappable".
///
/// This bar is instead rendered by `CustomerHomeShell` in the Scaffold's
/// `bottomNavigationBar` slot, stacked directly on top of the nav bar. That
/// slot is guaranteed by the Scaffold to sit below all content, above the
/// system gesture inset, and outside every nested `Scaffold`'s reach — nothing
/// can cover it, and no screen can scroll it away. No `SafeArea` is needed
/// here because the bottom navigation bar below it already consumes the
/// bottom inset.
class GuestSelectionBar extends ConsumerWidget {
  final GuestFleetSelection selection;

  const GuestSelectionBar({super.key, required this.selection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = selection.totalVehicles;
    return Material(
      color: AppColors.primaryBurgundy,
      elevation: 8,
      child: InkWell(
        onTap: () => context.push(RoutePaths.customerGroupBooking),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.local_shipping_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total ${total == 1 ? 'Car' : 'Cars'} Selected',
                      style: AppTypography.titleSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _summaryLine(selection.lines),
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: ElevatedButton(
                  // A real button, not a label: the action must LOOK like the
                  // one thing this bar is for.
                  onPressed: () => context.push(RoutePaths.customerGroupBooking),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.champagneGold,
                    foregroundColor: AppColors.primaryBurgundy,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Review Selection',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.primaryBurgundy,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// `Thar × 2 · Scorpio × 1` — the composition, not just a count.
  static String _summaryLine(List<GuestFleetLine> lines) => lines
      .map((l) => '${l.displayName} × ${l.quantity}')
      .join(' · ');
}
