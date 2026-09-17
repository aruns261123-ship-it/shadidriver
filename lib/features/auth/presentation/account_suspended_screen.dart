import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/shadi_card.dart';
import '../../../core/widgets/shadi_primary_button.dart';
import 'controllers/auth_controller.dart';

/// Screen displayed when an authenticated session belongs to a suspended account.
class AccountSuspendedScreen extends ConsumerWidget {
  const AccountSuspendedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: ShadiCard(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.red.shade200, width: 2),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.block_rounded,
                          color: Colors.red.shade700,
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Account Suspended',
                      style: AppTypography.titleLarge.copyWith(
                        color: AppColors.primaryBurgundy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Your ${AppConstants.appName} account is currently suspended by an administrator. Feature access, ride dispatch, and console operations are restricted.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondaryLight,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.secondarySurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.support_agent_rounded,
                            color: AppColors.primaryBurgundy,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Concierge Support Desk',
                                  style: AppTypography.labelSmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimaryLight,
                                  ),
                                ),
                                Text(
                                  'support@shadidriver.com • 1800-SHADI-VIP',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ShadiPrimaryButton(
                      text: 'Contact Concierge',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please contact concierge at support@shadidriver.com',
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        ref.read(authControllerProvider.notifier).signOut();
                      },
                      child: Text(
                        'Sign Out',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.primaryBurgundy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
