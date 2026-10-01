import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/shadi_card.dart';
import '../../../../core/widgets/shadi_primary_button.dart';

/// Wedding-search card on the customer home hero.
///
/// RESPONSIVE CONTRACT
/// -------------------
/// The two secondary fields (Event Date / Occasion) sit side by side only when
/// there is genuinely room for both; otherwise they STACK, separated by the
/// same hairline rule, and every field keeps its full width. The decision is
/// taken from the real content width (`LayoutBuilder`) and the text scale — not
/// from the screen width and not from a hardcoded pixel budget.
///
/// The previous implementation put both field texts in an unconstrained
/// `Column` inside a `Row`, so each label/value was laid out at its intrinsic
/// width inside a bounded half — 19px, 111px and 14px of overflow at 360dp
/// (and 132/189/63px at 1.3x text scale). Every text run here is now either
/// bounded by an [Expanded] or free to wrap, so nothing can overflow and
/// nothing is clipped. Verified by
/// `test/features/home/home_responsive_test.dart`.
class ShadiSearchCard extends StatelessWidget {
  final VoidCallback onSearch;

  const ShadiSearchCard({super.key, required this.onSearch});

  /// Minimum content width for a readable side-by-side pair: icon (24) + gap
  /// (12) + a usable text column (~110) for each field, plus the rule and its
  /// margins (33). Below this the fields stack.
  static const double _sideBySideMinContentWidth = 292;

  /// Past this text scale a side-by-side pair breaks values over two or three
  /// lines, which reads worse than a clean stack — so we stack instead of
  /// shrinking anything.
  static const double _sideBySideMaxTextScale = 1.2;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);

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
          LayoutBuilder(
            builder: (context, constraints) {
              final dateField = _buildInput(
                icon: Icons.calendar_today_rounded,
                label: 'Event Date',
                value: 'Nov 20, 2026',
              );
              final occasionField = _buildInput(
                icon: Icons.celebration_rounded,
                label: 'Occasion',
                value: 'Baraat',
              );

              final sideBySide =
                  constraints.maxWidth >= _sideBySideMinContentWidth &&
                  textScale <= _sideBySideMaxTextScale;

              if (!sideBySide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 32, color: AppColors.borderLight),
                    dateField,
                    const Divider(height: 32, color: AppColors.borderLight),
                    occasionField,
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 32, color: AppColors.borderLight),
                  Row(
                    children: [
                      Expanded(child: dateField),
                      Container(
                        width: 1,
                        height: 40,
                        color: AppColors.borderLight,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      Expanded(child: occasionField),
                    ],
                  ),
                ],
              );
            },
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, color: AppColors.champagneGold, size: 24),
        ),
        const SizedBox(width: 12),
        // Bounded: the label and the value WRAP inside whatever width the
        // field was given, so a long label or a large text scale reflows
        // instead of overflowing (and never ellipsizes information away).
        Expanded(
          child: Column(
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
        ),
      ],
    );
  }
}
