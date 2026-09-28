import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Shared `− n +` quantity control for a selected vehicle line.
///
/// Extracted so the vehicle card, the vehicle-details bar and the review
/// screen all render the SAME stepper — one selection model, one control, so
/// the quantity a visitor sets on any surface reads back identically on the
/// others.
///
/// [onDecrement] is called with no arguments; the owner decides what "minus at
/// one" means. Every current owner treats it as "remove the line", which is
/// what makes a selected vehicle removable from the very surface it was added
/// on.
class ShadiQuantityStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  /// Accent for the buttons and the count. Defaults to the verified-emerald
  /// "selected" tone used across the selection surfaces.
  final Color? accent;

  /// Larger hit targets for the review screen, compact for list cards.
  final bool compact;

  const ShadiQuantityStepper({
    super.key,
    required this.quantity,
    this.onDecrement,
    this.onIncrement,
    this.accent,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.verifiedEmerald;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: Icons.remove_rounded,
          tooltip: quantity <= 1
              ? 'Remove from selection'
              : 'Decrease quantity',
          color: color,
          compact: compact,
          onPressed: onDecrement,
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpacing.sm : AppSpacing.md,
          ),
          child: Text(
            '$quantity',
            style: (compact ? AppTypography.titleSmall : AppTypography.titleMedium)
                .copyWith(
              color: AppColors.textPrimaryLight,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _StepButton(
          icon: Icons.add_rounded,
          tooltip: 'Increase quantity',
          color: color,
          compact: compact,
          onPressed: onIncrement,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final bool compact;
  final VoidCallback? onPressed;

  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.compact,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 30.0 : 40.0;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color),
          ),
          child: Icon(icon, size: compact ? 18 : 22, color: color),
        ),
      ),
    );
  }
}
