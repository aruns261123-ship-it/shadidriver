import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Non-intrusive luxury status pill reassuring users and chauffeurs that offline caching
/// is active and trip itineraries remain accessible even without venue network coverage.
class ShadiOfflineBanner extends StatefulWidget {
  final String message;

  const ShadiOfflineBanner({
    super.key,
    this.message =
        'Local Offline Cache Active • All schedules and itineraries synced',
  });

  @override
  State<ShadiOfflineBanner> createState() => _ShadiOfflineBannerState();
}

class _ShadiOfflineBannerState extends State<ShadiOfflineBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E28),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.champagneGold.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_done_rounded,
            size: 16,
            color: AppColors.champagneGold,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.message,
              style: AppTypography.labelSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _dismissed = true),
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(Icons.close, size: 14, color: Colors.white60),
            ),
          ),
        ],
      ),
    );
  }
}
