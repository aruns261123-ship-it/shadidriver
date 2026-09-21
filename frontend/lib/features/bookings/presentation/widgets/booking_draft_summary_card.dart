import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/shadi_card.dart';
import '../../../../core/widgets/shadi_primary_button.dart';
import '../../../../core/widgets/shadi_secondary_button.dart';
import '../../../../core/widgets/shadi_status_badge.dart';
import '../../domain/entities/booking_draft.dart';

/// Luxury summary card presented when Milestone 4A draft is successfully saved.
class BookingDraftSummaryCard extends StatelessWidget {
  final BookingDraft draft;
  final VoidCallback onDismiss;
  final VoidCallback? onReview;

  const BookingDraftSummaryCard({
    super.key,
    required this.draft,
    required this.onDismiss,
    this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    return ShadiCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.verifiedEmerald,
                    size: 26,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Draft Created',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.primaryBurgundy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const ShadiStatusBadge(
                status: 'DRAFT',
                color: AppColors.warmGold,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Draft ID: ${draft.id}',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondaryLight,
              fontFamily: 'monospace',
            ),
          ),
          const Divider(height: 24, color: AppColors.borderLight),

          // Vehicle & Ceremony
          _buildRow('Vehicle', '${draft.vehicleName} (${draft.vehicleClass})'),
          const SizedBox(height: 8),
          _buildRow('Ceremony', draft.ceremonyType),
          const SizedBox(height: 8),
          _buildRow('Chauffeur Attire', draft.ceremonialAttire),
          const SizedBox(height: 8),

          // Date & Time
          _buildRow(
            'Date & Timing',
            '${DateFormatter.formatCeremonyDate(draft.serviceStartDateTime)} at ${draft.startTime.format(context)} → ${DateFormatter.formatCeremonyDate(draft.serviceEndDateTime)} at ${draft.endTime.format(context)} (${draft.formattedDuration})',
          ),
          if (draft.routeDistanceKm != null) ...[
            const SizedBox(height: 8),
            _buildRow(
              'Route Distance',
              '~${draft.routeDistanceKm!.toStringAsFixed(1)} km (Est.)',
            ),
          ],
          const SizedBox(height: 8),

          // Locations
          _buildRow('Pickup', draft.pickupAddress),
          const SizedBox(height: 8),
          _buildRow(
            'Destination',
            draft.venueName.isNotEmpty
                ? '${draft.venueName} - ${draft.destinationAddress}'
                : draft.destinationAddress,
          ),
          const SizedBox(height: 8),

          // Host Contact
          _buildRow(
            'Primary Host',
            '${draft.primaryContactName} (${draft.primaryContactPhone}) • ${draft.passengerCount} Passengers',
          ),

          const Divider(height: 24, color: AppColors.borderLight),

          // Quotation Preview
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Estimated Total',
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.textPrimaryLight,
                ),
              ),
              Text(
                CurrencyFormatter.formatPaise(draft.estimatedTotalPaise),
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.primaryBurgundy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                draft.advanceTokenLabel,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
              Text(
                CurrencyFormatter.formatPaise(draft.advanceTokenPaise),
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.warmGold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondarySurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.champagneGold.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.warmGold,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Milestone 4A complete. Booking draft saved. Advance token payment will unlock in Milestone 4B.',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (onReview != null) ...[
            ShadiPrimaryButton(
              text: 'Review & Submit Booking',
              onPressed: onReview,
            ),
            const SizedBox(height: 10),
            ShadiSecondaryButton(text: 'Return to Home', onPressed: onDismiss),
          ] else ...[
            ShadiPrimaryButton(text: 'Return to Home', onPressed: onDismiss),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondaryLight,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimaryLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
