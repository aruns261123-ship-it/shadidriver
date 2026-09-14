import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/shadi_card.dart';
import '../../../core/widgets/shadi_primary_button.dart';
import '../../../core/widgets/shadi_section_header.dart';
import '../../../core/widgets/shadi_status_badge.dart';
import '../../../core/widgets/shadi_verification_badge.dart';

/// Customer application shell placeholder demonstrating foundational UI components.
class CustomerHomePlaceholderScreen extends StatelessWidget {
  const CustomerHomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ShadiDriver'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: 'Switch Portal',
            onPressed: () => context.go(RoutePaths.auth),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const ShadiSectionHeader(
            title: 'Ceremonial Chauffeurs',
            subtitle: 'Verified luxury mobility for your wedding festivities',
          ),
          const SizedBox(height: 16),
          ShadiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    ShadiVerificationBadge(),
                    ShadiStatusBadge(status: 'CONFIRMED'),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Baraat Lead Chauffeur',
                  style: AppTypography.titleLarge.copyWith(
                    color: AppColors.primaryBurgundy,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Mercedes-Benz E-Class • Royal Bandhgala & Safa Attire',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Phase 0 Architecture Foundation',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textTertiaryLight,
                      ),
                    ),
                    const ShadiStatusBadge(
                      status: 'READY',
                      color: AppColors.champagneGold,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const ShadiSectionHeader(
            title: 'Portal Navigation',
            subtitle:
                'Preview architecture-ready shells for all platform roles',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ShadiPrimaryButton(
                  text: 'Driver Shell',
                  onPressed: () => context.go(RoutePaths.driver),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ShadiPrimaryButton(
                  text: 'Admin Shell',
                  onPressed: () => context.go(RoutePaths.admin),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
