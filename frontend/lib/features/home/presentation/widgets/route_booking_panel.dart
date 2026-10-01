import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/shadi_primary_button.dart';
import '../../../search/domain/entities/trip_type.dart';

/// Trip direction for the booking panel's segmented control.
enum TripDirection { oneWay, bothWay }

/// Maps the panel's presentation enum onto the canonical domain value that
/// travels to search, quote and booking (ONE_WAY | ROUND_TRIP).
extension TripDirectionX on TripDirection {
  TripType get wire =>
      this == TripDirection.bothWay ? TripType.roundTrip : TripType.oneWay;
}

/// The reference booking panel (PAGE 02 · Customer Home): an ivory card that
/// overlaps the hero, containing the pickup/destination route inputs joined by
/// a dashed gold connector, the One Way / Both Way segmented control, and the
/// full-width burgundy "Find Cars" CTA.
class RouteBookingPanel extends StatelessWidget {
  final String pickupValue;
  final String destinationValue;
  final TripDirection tripDirection;
  final ValueChanged<TripDirection> onTripChanged;
  final VoidCallback onFindCars;
  final VoidCallback? onPickupTap;
  final VoidCallback? onDestinationTap;

  const RouteBookingPanel({
    super.key,
    required this.tripDirection,
    required this.onTripChanged,
    required this.onFindCars,
    this.pickupValue = 'Use current location',
    this.destinationValue = '',
    this.onPickupTap,
    this.onDestinationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      // The panel's -17dp top offset from the reference, pulling it over the
      // hero's bottom edge.
      offset: const Offset(0, -17),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.ivory,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14140509),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RouteInputs(
              pickupValue: pickupValue,
              destinationValue: destinationValue,
              onPickupTap: onPickupTap,
              onDestinationTap: onDestinationTap,
            ),
            const SizedBox(height: 13),
            // The label and the segmented control share one line when they
            // fit and the control wraps below the label when they do not —
            // a Wrap cannot overflow, so this holds at every width and text
            // scale (a Row here overflowed by 12–27px at 375–390dp).
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              children: [
                Text(
                  'Trip type',
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                _TripSegmentedControl(
                  direction: tripDirection,
                  onChanged: onTripChanged,
                ),
              ],
            ),
            const SizedBox(height: 13),
            ShadiPrimaryButton(
              text: 'Find Cars',
              icon: Icons.arrow_forward_rounded,
              onPressed: onFindCars,
            ),
          ],
        ),
      ),
    );
  }
}

/// The joined pickup/destination pair with the dashed gold route line.
class _RouteInputs extends StatelessWidget {
  final String pickupValue;
  final String destinationValue;
  final VoidCallback? onPickupTap;
  final VoidCallback? onDestinationTap;

  const _RouteInputs({
    required this.pickupValue,
    required this.destinationValue,
    this.onPickupTap,
    this.onDestinationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderLight),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              _RouteField(
                icon: Icons.my_location_rounded,
                value: pickupValue,
                hint: 'Use current location',
                onTap: onPickupTap,
              ),
              Container(height: 1, color: AppColors.borderLight),
              _RouteField(
                icon: Icons.location_on_rounded,
                value: destinationValue,
                hint: 'Enter destination',
                onTap: onDestinationTap,
              ),
            ],
          ),
          // The dashed connector between the two fields.
          Positioned(
            left: 20,
            top: 0,
            bottom: 0,
            child: Center(
              child: CustomPaint(
                size: const Size(1, 18),
                painter: _DashedLinePainter(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteField extends StatelessWidget {
  final IconData icon;
  final String value;
  final String hint;
  final VoidCallback? onTap;

  const _RouteField({
    required this.icon,
    required this.value,
    required this.hint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 45),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryBurgundy),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  value.isEmpty ? hint : value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(
                    color: value.isEmpty
                        ? AppColors.textTertiaryLight
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.champagneGold
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    const dashHeight = 3.0;
    const gap = 3.0;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, y + dashHeight),
        paint,
      );
      y += dashHeight + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TripSegmentedControl extends StatelessWidget {
  final TripDirection direction;
  final ValueChanged<TripDirection> onChanged;

  const _TripSegmentedControl({
    required this.direction,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.secondarySurface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(9),
      ),
      // Flexible (not Expanded) so the control shrink-wraps inside the
      // side-by-side row; in stacked mode the parent's full-width SizedBox
      // gives it room and the segments share it evenly.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: _Segment(
              label: 'One Way',
              selected: direction == TripDirection.oneWay,
              onTap: () => onChanged(TripDirection.oneWay),
            ),
          ),
          Flexible(
            child: _Segment(
              label: 'Both Way',
              selected: direction == TripDirection.bothWay,
              onTap: () => onChanged(TripDirection.bothWay),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: selected
                ? [
                    const BoxShadow(
                      color: Color(0x0F000000),
                      blurRadius: 7,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: selected
                  ? AppColors.primaryBurgundy
                  : AppColors.textSecondaryLight,
            ),
          ),
        ),
      ),
    );
  }
}
