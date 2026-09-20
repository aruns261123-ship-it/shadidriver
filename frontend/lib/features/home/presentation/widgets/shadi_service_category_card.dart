import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../services/domain/entities/service_category.dart';

class ShadiServiceCategoryCard extends StatelessWidget {
  final ServiceCategory category;
  final VoidCallback onTap;

  const ShadiServiceCategoryCard({
    super.key,
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.secondarySurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Icon(
              _getIcon(category.id),
              color: AppColors.primaryBurgundy,
              size: 32,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            category.name,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textPrimaryLight,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String id) {
    switch (id) {
      case 'c1':
        return Icons.directions_car_rounded;
      case 'c2':
        return Icons.girl_rounded;
      case 'c3':
        return Icons.man_rounded;
      case 'c4':
        return Icons.music_note_rounded;
      case 'c5':
        return Icons.favorite_rounded;
      case 'c6':
        return Icons.groups_rounded;
      case 'c7':
        return Icons.flight_takeoff_rounded;
      case 'c8':
        return Icons.camera_alt_rounded;
      default:
        return Icons.celebration_rounded;
    }
  }
}
