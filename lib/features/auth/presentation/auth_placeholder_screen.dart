import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/shadi_card.dart';
import '../../../core/widgets/shadi_primary_button.dart';
import '../../../core/widgets/shadi_secondary_button.dart';

/// Architecture-ready authentication placeholder screen.
class AuthPlaceholderScreen extends StatelessWidget {
  const AuthPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Authentication')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ShadiCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_person_rounded,
                    size: 48,
                    color: AppColors.champagneGold,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ShadiDriver Access Portal',
                    style: AppTypography.titleLarge.copyWith(
                      color: AppColors.primaryBurgundy,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Phase 0 Architecture Foundation\nReal Phone OTP will be implemented in Phase 1.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ShadiPrimaryButton(
                    text: 'Continue as Customer',
                    onPressed: () => context.go(RoutePaths.customer),
                  ),
                  const SizedBox(height: 12),
                  ShadiSecondaryButton(
                    text: 'Continue as Driver',
                    onPressed: () => context.go(RoutePaths.driver),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go(RoutePaths.admin),
                    child: Text(
                      'Admin Control Room Preview',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.primaryBurgundy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
