import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/shadi_primary_button.dart';

/// Entry placeholder screen for booking flow (Milestone 3 -> Milestone 4 bridge).
class BookingEntryPlaceholderScreen extends StatelessWidget {
  final String vehicleId;

  const BookingEntryPlaceholderScreen({super.key, required this.vehicleId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Book Vehicle',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.primaryBurgundy,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.secondarySurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_today_rounded,
                size: 48,
                color: AppColors.primaryBurgundy,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Booking Experience',
              style: AppTypography.displaySmall.copyWith(
                color: AppColors.primaryBurgundy,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Vehicle ID: $vehicleId',
              style: AppTypography.titleSmall.copyWith(
                color: AppColors.warmGold,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You have selected vehicle $vehicleId. Proceeding to event details and schedule booking.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ShadiPrimaryButton(
              text: 'Return to Details',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
