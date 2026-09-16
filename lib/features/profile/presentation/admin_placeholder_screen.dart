import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/shadi_card.dart';
import '../../../core/widgets/shadi_primary_button.dart';
import '../../../core/widgets/shadi_section_header.dart';
import '../../../core/widgets/shadi_status_badge.dart';

/// Admin operations control room placeholder.
class AdminPlaceholderScreen extends StatelessWidget {
  const AdminPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Operations Control'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Admin Profile & Security',
            onPressed: () => context.push(RoutePaths.adminProfile),
          ),
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
            title: 'Operations Overview',
            subtitle: 'Verification pipeline and live wedding dispatch monitor',
          ),
          const SizedBox(height: 16),
          ShadiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('System Health:', style: AppTypography.titleMedium),
                    ShadiStatusBadge(
                      status: 'OPERATIONAL',
                      color: AppColors.verifiedEmerald,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Admin Dashboard Shell (Phase 0)\nVerification queues and control room will be implemented in subsequent phases.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 16),
                ShadiPrimaryButton(
                  text: 'Admin Profile & Security Credentials',
                  onPressed: () => context.push(RoutePaths.adminProfile),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => context.go(RoutePaths.customer),
                  child: const Center(child: Text('Return to Customer View')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
