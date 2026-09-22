import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Luxury custom vector map canvas representing ceremonial wedding routes
/// between pickup venue, procession gate, and banquet hall.
class ShadiCeremonialRouteMap extends StatelessWidget {
  final String pickupLocation;
  final String? milestoneLocation;
  final String destinationLocation;
  final String distance;
  final String duration;
  final double height;
  final bool isLive;
  final VoidCallback? onTap;

  const ShadiCeremonialRouteMap({
    super.key,
    required this.pickupLocation,
    this.milestoneLocation,
    required this.destinationLocation,
    this.distance = '14.2 km',
    this.duration = '32 mins',
    this.height = 180,
    this.isLive = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF16151D),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.champagneGold.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // 1. Vector Map Canvas
            Positioned.fill(
              child: CustomPaint(painter: _CeremonialRoutePainter()),
            ),

            // 2. Top-left Status Badge (Live GPS Telemetry)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isLive
                        ? AppColors.verifiedEmerald
                        : AppColors.champagneGold,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isLive
                            ? AppColors.verifiedEmerald
                            : AppColors.champagneGold,
                        boxShadow: [
                          BoxShadow(
                            color:
                                (isLive
                                        ? AppColors.verifiedEmerald
                                        : AppColors.champagneGold)
                                    .withValues(alpha: 0.8),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isLive ? 'LIVE GPS ROUTE' : 'CEREMONIAL ITINERARY',
                      style: AppTypography.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Top-right Distance & ETA Badge
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.champagneGold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.champagneGold,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 13,
                      color: AppColors.softChampagne,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$duration • $distance',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.softChampagne,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4. Bottom Itinerary Overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.95),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.radio_button_checked,
                                size: 12,
                                color: AppColors.champagneGold,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  pickupLocation,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.labelSmall.copyWith(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 12,
                                color: Color(0xFFFF5252),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  destinationLocation,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.labelSmall.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.open_in_full_rounded,
                        size: 15,
                        color: AppColors.champagneGold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter rendering stylized route curves, coordinates, and royal nodes.
class _CeremonialRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1.0;

    // Subtle grid lines
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Secondary decorative transit roads
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final roadPath = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.4,
        size.height * 0.9,
        size.width,
        size.height * 0.45,
      );
    canvas.drawPath(roadPath, roadPaint);

    // Primary Ceremonial Route (Gilded Curve)
    final pStart = Offset(size.width * 0.16, size.height * 0.55);
    final pMid1 = Offset(size.width * 0.42, size.height * 0.28);
    final pMid2 = Offset(size.width * 0.68, size.height * 0.72);
    final pEnd = Offset(size.width * 0.88, size.height * 0.38);

    final routePath = Path()
      ..moveTo(pStart.dx, pStart.dy)
      ..cubicTo(pMid1.dx, pMid1.dy, pMid2.dx, pMid2.dy, pEnd.dx, pEnd.dy);

    // Route Glow
    final glowPaint = Paint()
      ..color = AppColors.champagneGold.withValues(alpha: 0.25)
      ..strokeWidth = 9.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(routePath, glowPaint);

    // Main Route Line
    final routePaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          AppColors.champagneGold,
          AppColors.warmGold,
          Color(0xFFFFF275),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 3.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(routePath, routePaint);

    // Node 1: Pickup Venue
    _drawWaypointNode(
      canvas,
      pStart,
      glowColor: AppColors.champagneGold.withValues(alpha: 0.4),
      innerColor: AppColors.champagneGold,
      outerRadius: 9,
      innerRadius: 4,
    );

    // Node 2: Ceremonial Baraat Assembly Waypoint
    final pMidPoint = Offset(size.width * 0.55, size.height * 0.52);
    _drawDiamondWaypoint(canvas, pMidPoint);

    // Node 3: Banquet Hall Destination
    _drawWaypointNode(
      canvas,
      pEnd,
      glowColor: const Color(0xFFFF5252).withValues(alpha: 0.45),
      innerColor: const Color(0xFFFF5252),
      outerRadius: 10,
      innerRadius: 4.5,
    );
  }

  void _drawWaypointNode(
    Canvas canvas,
    Offset position, {
    required Color glowColor,
    required Color innerColor,
    required double outerRadius,
    required double innerRadius,
  }) {
    // Outer glow
    canvas.drawCircle(position, outerRadius + 4, Paint()..color = glowColor);
    // Outer ring
    canvas.drawCircle(
      position,
      outerRadius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    // Inner center
    canvas.drawCircle(
      position,
      innerRadius,
      Paint()
        ..color = innerColor
        ..style = PaintingStyle.fill,
    );
  }

  void _drawDiamondWaypoint(Canvas canvas, Offset center) {
    const size = 6.0;
    final path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..lineTo(center.dx + size, center.dy)
      ..lineTo(center.dx, center.dy + size)
      ..lineTo(center.dx - size, center.dy)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.champagneGold.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
