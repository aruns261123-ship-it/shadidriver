import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// The reference spec grid (PAGE 02 · Car details): up to four columns per row
/// separated by hairlines, each cell a burgundy icon above a tiny caption.
/// Extra specs wrap onto additional rows, so the grid holds any data without
/// horizontal overflow.
class VehicleSpecsGrid extends StatelessWidget {
  final List<({IconData icon, String label})> specs;

  const VehicleSpecsGrid({super.key, required this.specs});

  @override
  Widget build(BuildContext context) {
    if (specs.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderLight),
        borderRadius: BorderRadius.circular(13),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Four columns on a normal phone; two on very narrow content so a
          // cell never squeezes below a readable width.
          final columns = constraints.maxWidth >= 300 ? 4 : 2;
          final rows = <List<({IconData icon, String label})>>[];
          for (var i = 0; i < specs.length; i += columns) {
            rows.add(
              specs.sublist(
                i,
                i + columns > specs.length ? specs.length : i + columns,
              ),
            );
          }

          return Column(
            children: [
              for (var r = 0; r < rows.length; r++) ...[
                if (r > 0) ...[
                  const SizedBox(height: 12),
                  Container(height: 1, color: AppColors.borderLight),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    for (var i = 0; i < rows[r].length; i++) ...[
                      if (i > 0)
                        Container(
                          width: 1,
                          height: 34,
                          color: AppColors.borderLight,
                        ),
                      Expanded(
                        child: Column(
                          children: [
                            Icon(
                              rows[r][i].icon,
                              size: 18,
                              color: AppColors.primaryBurgundy,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              rows[r][i].label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelSmall.copyWith(
                                fontSize: 7,
                                color: AppColors.textSecondaryLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
