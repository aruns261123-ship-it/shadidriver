import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/shadi_card.dart';
import '../../../../core/widgets/shadi_primary_button.dart';

class ShadiSearchCard extends StatelessWidget {
  final VoidCallback onSearch;

  const ShadiSearchCard({super.key, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return ShadiCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInput(
            icon: Icons.location_on_rounded,
            label: 'City / Pickup Location',
            value: 'Delhi NCR',
          ),
          const Divider(height: 32, color: AppColors.borderLight),
          Row(
            children: [
              Expanded(
                child: _buildInput(
                  icon: Icons.calendar_today_rounded,
                  label: 'Event Date',
                  value: 'Nov 20, 2026',
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: AppColors.borderLight,
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              Expanded(
                child: _buildInput(
                  icon: Icons.celebration_rounded,
                  label: 'Occasion',
                  value: 'Baraat',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ShadiPrimaryButton(text: 'Find a Chauffeur', onPressed: onSearch),
        ],
      ),
    );
  }

  Widget _buildInput({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.champagneGold, size: 24),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textTertiaryLight,
              ),
            ),
            Text(
              value,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
