import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/shadi_tokens.dart';
import 'shadi_ref_typography.dart';

/// One step in the reference onboarding step system (PAGE 03): the 2-column
/// grid of pill cards where completed steps carry a green check, the active
/// step is champagne with a burgundy number, and pending steps are plain.
class ShadiOnboardingStep {
  final String label;

  const ShadiOnboardingStep(this.label);
}

/// The reference step list: `display: grid; grid-template-columns: 1fr 1fr;
/// gap: 9px`, cards 11px padding / radius 11, 23px numbered circles.
class ShadiOnboardingSteps extends StatelessWidget {
  final List<ShadiOnboardingStep> steps;

  /// Zero-based index of the current step.
  final int currentStep;

  const ShadiOnboardingSteps({
    super.key,
    required this.steps,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The reference is a 2-column grid; a single column on very narrow
        // content keeps every label readable.
        final columns = constraints.maxWidth >= 300 ? 2 : 1;
        final rows = <List<int>>[];
        for (var i = 0; i < steps.length; i += columns) {
          rows.add(
            List.generate(
              i + columns > steps.length ? steps.length - i : columns,
              (j) => i + j,
            ),
          );
        }
        return Column(
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) const SizedBox(height: 9),
              Row(
                children: [
                  for (var c = 0; c < rows[r].length; c++) ...[
                    if (c > 0) const SizedBox(width: 9),
                    Expanded(
                      child: _StepCard(
                        index: rows[r][c],
                        label: steps[rows[r][c]].label,
                        state: rows[r][c] < currentStep
                            ? _StepState.done
                            : rows[r][c] == currentStep
                                ? _StepState.active
                                : _StepState.pending,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

enum _StepState { done, active, pending }

class _StepCard extends StatelessWidget {
  final int index;
  final String label;
  final _StepState state;

  const _StepCard({
    required this.index,
    required this.label,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final isChampagne = state == _StepState.active;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: isChampagne
            ? ShadiColors.champagne
            : (state == _StepState.done ? AppColors.ivory : AppColors.ivory),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: isChampagne ? ShadiColors.gold : ShadiColors.line,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 23,
            height: 23,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: state == _StepState.active
                  ? AppColors.primaryBurgundy
                  : (state == _StepState.done
                      ? ShadiColors.greenSoft
                      : ShadiColors.neutralBadgeBg),
            ),
            child: state == _StepState.done
                ? const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: ShadiColors.green,
                  )
                : Center(
                    child: Text(
                      '${index + 1}',
                      style: ShadiRefType.ui8.copyWith(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: state == _StepState.active
                            ? Colors.white
                            : ShadiColors.muted,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSmall.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
