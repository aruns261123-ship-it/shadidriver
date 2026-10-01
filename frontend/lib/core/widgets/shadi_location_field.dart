import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Location input from the design system (PAGE 01 · FORM): a 56dp white box
/// with a thin border, a burgundy leading icon, the value, and a trailing
/// chevron. The whole field is one tap target.
class ShadiLocationField extends StatelessWidget {
  final String? label;
  final String value;
  final String? hint;
  final IconData icon;
  final VoidCallback? onTap;

  const ShadiLocationField({
    super.key,
    this.label,
    required this.value,
    this.hint,
    this.icon = Icons.location_on_outlined,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final field = Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primaryBurgundy),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              value.isEmpty ? (hint ?? '') : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium.copyWith(
                color: value.isEmpty
                    ? AppColors.textTertiaryLight
                    : AppColors.textPrimaryLight,
              ),
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 17,
            color: AppColors.textTertiaryLight,
          ),
        ],
      ),
    );

    if (label == null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: field,
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label!.toUpperCase(),
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textTertiaryLight,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              fontSize: 9,
            ),
          ),
          const SizedBox(height: 6),
          field,
        ],
      ),
    );
  }
}
