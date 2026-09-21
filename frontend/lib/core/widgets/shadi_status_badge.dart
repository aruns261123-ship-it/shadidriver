import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Dynamic status pill badge for booking and verification states.
class ShadiStatusBadge extends StatelessWidget {
  final String status;
  final Color? color;

  const ShadiStatusBadge({super.key, required this.status, this.color});

  @override
  Widget build(BuildContext context) {
    final badgeColor = color ?? _resolveStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: AppTypography.labelSmall.copyWith(
          color: badgeColor,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Color _resolveStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
      case 'COMPLETED':
      case 'APPROVED':
      case 'VERIFIED':
        return AppColors.verifiedEmerald;

      case 'REQUESTED':
      case 'DRIVER_ACCEPTED':
      case 'PAYMENT_PENDING':
      case 'UNDER_REVIEW':
      case 'SUBMITTED':
        return AppColors.warmGold;

      case 'DRIVER_ARRIVING':
      case 'ARRIVED':
      case 'TRIP_STARTED':
        return AppColors.primaryBurgundy;

      case 'EMERGENCY_REPLACEMENT':
      case 'ACTION_REQUIRED':
        return AppColors.urgentSaffron;

      case 'CANCELLED':
      case 'REJECTED':
      case 'EXPIRED':
      case 'PAYMENT_FAILED':
      case 'SUSPENDED':
        return AppColors.errorRed;

      default:
        return AppColors.textSecondaryLight;
    }
  }
}
