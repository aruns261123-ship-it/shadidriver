import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Luxury live countdown ticker for auspicious wedding Muhurat ceremony timings.
class ShadiMuhuratCountdownTicker extends StatefulWidget {
  final DateTime? targetTime;
  final String ceremonyName;
  final String? venueName;

  const ShadiMuhuratCountdownTicker({
    super.key,
    this.targetTime,
    this.ceremonyName = 'Auspicious Muhurat Window',
    this.venueName,
  });

  @override
  State<ShadiMuhuratCountdownTicker> createState() =>
      _ShadiMuhuratCountdownTickerState();
}

class _ShadiMuhuratCountdownTickerState
    extends State<ShadiMuhuratCountdownTicker> {
  Timer? _timer;
  late DateTime _target;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    // Default to 4 hours and 15 mins from now if no target time provided
    _target =
        widget.targetTime ??
        DateTime.now().add(const Duration(hours: 4, minutes: 15, seconds: 30));
    _remaining = _calculateRemaining();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant ShadiMuhuratCountdownTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetTime != oldWidget.targetTime) {
      _target =
          widget.targetTime ??
          DateTime.now().add(const Duration(hours: 4, minutes: 15));
      _remaining = _calculateRemaining();
    }
  }

  Duration _calculateRemaining() {
    final diff = _target.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final newRemaining = _calculateRemaining();
      setState(() {
        _remaining = newRemaining;
      });
      if (newRemaining == Duration.zero) {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2E0911),
            AppColors.primaryBurgundy,
            Color(0xFF3F0A14),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.champagneGold.withValues(alpha: 0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBurgundy.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.champagneGold.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: AppColors.softChampagne,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.ceremonyName.toUpperCase(),
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.softChampagne,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        fontSize: 10,
                      ),
                    ),
                    if (widget.venueName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.venueName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warmGold.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.champagneGold.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  'LAGNA COUNTDOWN',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.softChampagne,
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Ticker Unit Boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (days > 0) ...[
                _buildTimeUnit(days.toString().padLeft(2, '0'), 'DAYS'),
                _buildColon(),
              ],
              _buildTimeUnit(hours.toString().padLeft(2, '0'), 'HOURS'),
              _buildColon(),
              _buildTimeUnit(minutes.toString().padLeft(2, '0'), 'MINS'),
              _buildColon(),
              _buildTimeUnit(seconds.toString().padLeft(2, '0'), 'SECS'),
            ],
          ),
          const SizedBox(height: 10),

          // Standby Assurance footer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 13,
                color: AppColors.softChampagne,
              ),
              const SizedBox(width: 5),
              Text(
                'Royal Chauffeur on standby 45 mins prior to the holy hour',
                style: AppTypography.labelSmall.copyWith(
                  color: Colors.white70,
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeUnit(String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.champagneGold.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            value,
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.softChampagne,
              fontWeight: FontWeight.w800,
              fontSize: 20,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.champagneGold.withValues(alpha: 0.8),
            fontWeight: FontWeight.w700,
            fontSize: 9,
          ),
        ),
      ],
    );
  }

  Widget _buildColon() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        ':',
        style: AppTypography.titleMedium.copyWith(
          color: AppColors.softChampagne,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
