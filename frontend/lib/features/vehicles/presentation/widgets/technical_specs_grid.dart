import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/shadi_card.dart';
import '../../../../core/widgets/shadi_verification_badge.dart';
import '../../domain/entities/vehicle_details.dart';

/// Grid displaying key technical specifications, verification, and availability.
class TechnicalSpecsGrid extends StatelessWidget {
  final VehicleDetails vehicle;

  const TechnicalSpecsGrid({super.key, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final vehicleAge = 2026 - vehicle.year;
    final ageText = vehicleAge <= 0 ? 'Brand New' : '$vehicleAge yrs';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top status pills: Verified Vehicle + Distinct Availability state
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (vehicle.verificationStatus == 'VERIFIED')
              const ShadiVerificationBadge(label: 'VERIFIED VEHICLE')
            else
              _buildPill(
                label: 'PENDING INSPECTION',
                color: AppColors.warmGold,
                icon: Icons.hourglass_empty_rounded,
              ),
            if (vehicle.isAvailableNow)
              _buildPill(
                label: 'AVAILABLE NOW',
                color: AppColors.urgentSaffron,
                icon: Icons.bolt_rounded,
              )
            else
              _buildPill(
                label: 'AVAILABLE FOR BOOKING',
                color: AppColors.primaryBurgundy,
                icon: Icons.event_available_rounded,
              ),
          ],
        ),
        const SizedBox(height: 16),
        // 2x2 Grid of Technical Specifications
        Row(
          children: [
            Expanded(
              child: _buildSpecCard(
                icon: Icons.event_seat_rounded,
                label: 'Seating',
                value: '${vehicle.seatingCapacity} Passengers',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSpecCard(
                icon: Icons.speed_rounded,
                label: 'Transmission',
                value: vehicle.transmission ?? 'Automatic',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSpecCard(
                icon: Icons.calendar_today_rounded,
                label: 'Model Year',
                value: '${vehicle.year} ($ageText)',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSpecCard(
                icon: Icons.category_rounded,
                label: 'Category',
                value: vehicle.vehicleClass,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpecCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return ShadiCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      backgroundColor: AppColors.secondarySurface,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: AppColors.warmGold),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiaryLight,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.textPrimaryLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
