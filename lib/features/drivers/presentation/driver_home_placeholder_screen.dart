import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/shadi_card.dart';
import '../../../core/widgets/shadi_primary_button.dart';
import '../../../core/widgets/shadi_section_header.dart';
import '../../../core/widgets/shadi_status_badge.dart';

/// Driver portal application shell placeholder.
class DriverHomePlaceholderScreen extends StatelessWidget {
  const DriverHomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chauffeur Portal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: 'Switch Portal',
            onPressed: () => context.go(RoutePaths.customer),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const ShadiSectionHeader(
            title: 'Chauffeur Console',
            subtitle: 'Real-time job dispatch and ceremonial duty rosters',
          ),
          const SizedBox(height: 16),
          ShadiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Current Status:', style: AppTypography.titleMedium),
                    ShadiStatusBadge(
                      status: 'STANDBY',
                      color: AppColors.champagneGold,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Driver Workflows Placeholder (Phase 0)',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 16),
                ShadiPrimaryButton(
                  text: 'Return to Customer View',
                  onPressed: () => context.go(RoutePaths.customer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
