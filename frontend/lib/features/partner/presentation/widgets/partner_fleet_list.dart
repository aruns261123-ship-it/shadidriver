import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/widgets/shadi_card.dart';
import '../../../../../core/widgets/shadi_status_badge.dart';
import '../../domain/entities/partner_vehicle.dart';
import '../controllers/partner_onboarding_controller.dart';

/// "MY FLEET" — the partner's vehicles with per-vehicle verification state.
class PartnerFleetList extends ConsumerWidget {
  final PartnerFleet fleet;

  const PartnerFleetList({super.key, required this.fleet});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('MY FLEET',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  )),
            ),
            Text('${fleet.total} ${fleet.total == 1 ? 'Vehicle' : 'Vehicles'}',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.textSecondaryLight,
                )),
          ],
        ),
        const SizedBox(height: 6),
        // "2 Verified · 1 Under Review · 1 Changes Required"
        Text(fleet.tallyLine,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondaryLight,
            )),
        const SizedBox(height: 12),
        for (final v in fleet.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PartnerVehicleCard(vehicle: v),
          ),
      ],
    );
  }
}

class PartnerVehicleCard extends ConsumerWidget {
  final PartnerVehicle vehicle;

  const PartnerVehicleCard({super.key, required this.vehicle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(partnerOnboardingProvider.notifier);
    return ShadiCard(
      onTap: () => controller.startEditVehicle(vehicle),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // photo (or placeholder)
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.secondarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.directions_car_filled_rounded,
                color: AppColors.borderLight),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.displayName ?? vehicle.fleetCode,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${vehicle.year} · ${vehicle.color} · ${vehicle.maskedRegistration}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ShadiStatusBadge(status: vehicle.verificationStatus.wire),
                    const SizedBox(width: 6),
                    if (vehicle.isBookable)
                      const Icon(Icons.verified_rounded,
                          size: 16, color: AppColors.verifiedEmerald),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.borderLight),
        ],
      ),
    );
  }
}
