import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Circular round action button from the reference system: a translucent white
/// disc over photos, or a bordered white disc in plain app bars ([bordered]).
class ShadiRoundActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool bordered;
  final bool translucent;
  final double size;

  const ShadiRoundActionButton(
    this.icon, {
    super.key,
    this.onTap,
    this.tooltip,
    this.bordered = false,
    this.translucent = false,
    this.size = 39,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = translucent
        ? BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          )
        : BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            shape: BoxShape.circle,
            border: bordered
                ? Border.all(color: AppColors.borderLight)
                : null,
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 13,
                offset: Offset(0, 4),
              ),
            ],
          );

    final button = Material(
      color: Colors.transparent,
      child: Ink(
        width: size,
        height: size,
        decoration: decoration,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Icon(
            icon,
            size: size * 20 / 39,
            color: translucent ? Colors.white : AppColors.primaryBurgundy,
          ),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
