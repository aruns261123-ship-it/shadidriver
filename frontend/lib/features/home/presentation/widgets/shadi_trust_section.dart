import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/shadi_card.dart';

class ShadiTrustSection extends StatelessWidget {
  const ShadiTrustSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadiCard(
      backgroundColor: AppColors.primaryBurgundy,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.verified_user_rounded,
                color: AppColors.champagneGold,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Royal Assurance',
                style: AppTypography.displaySmall.copyWith(
                  color: AppColors.ivory,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildTrustItem(
            Icons.stars_rounded,
            'Verified Chauffeurs',
            'Expertly trained for ceremonial etiquette.',
          ),
          const SizedBox(height: 16),
          _buildTrustItem(
            Icons.shield_rounded,
            'Verified Vehicles',
            'Rigorous quality and aesthetic inspections.',
          ),
          const SizedBox(height: 16),
          _buildTrustItem(
            Icons.account_balance_wallet_rounded,
            'Transparent Pricing',
            'No hidden costs for your celebrations.',
          ),
          const SizedBox(height: 16),
          _buildTrustItem(
            Icons.support_agent_rounded,
            'Wedding-focused Support',
            'Dedicated team for your special moments.',
          ),
        ],
      ),
    );
  }

  Widget _buildTrustItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.champagneGold, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.ivory,
                ),
              ),
              Text(
                subtitle,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.ivory.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
