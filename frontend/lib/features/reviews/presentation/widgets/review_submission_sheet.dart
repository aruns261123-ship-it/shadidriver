import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/shadi_primary_button.dart';
import '../controllers/review_controller.dart';

/// Post-ceremony review bottom sheet: overall star rating, punctuality and
/// grooming sub-ratings, and free-text feedback for the ceremonial chauffeur.
Future<void> showReviewSubmissionSheet(
  BuildContext context,
  WidgetRef ref,
  String bookingId,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => Consumer(
      builder: (context, sheetRef, _) {
        final controller = sheetRef.read(
          reviewControllerProvider(bookingId).notifier,
        );
        final state = sheetRef.watch(reviewControllerProvider(bookingId));

        int overall = 5;
        int punctuality = 5;
        int grooming = 5;
        final feedbackController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setSheetState) {
            void setOverall(int value) => setSheetState(() => overall = value);

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rate Your Ceremony',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryBurgundy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your feedback honors the chauffeur who served your family.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Overall rating
                  _RatingRow(
                    label: 'Overall Experience',
                    value: overall,
                    onChanged: setOverall,
                  ),
                  const SizedBox(height: 8),
                  _RatingRow(
                    label: 'Punctuality',
                    value: punctuality,
                    onChanged: (v) => setSheetState(() => punctuality = v),
                  ),
                  const SizedBox(height: 8),
                  _RatingRow(
                    label: 'Chauffeur Grooming & Attire',
                    value: grooming,
                    onChanged: (v) => setSheetState(() => grooming = v),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    key: const Key('review_feedback_field'),
                    controller: feedbackController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText:
                          'Share highlights — punctuality, ceremony pacing, hospitality…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (state.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        state.errorMessage!,
                        style: AppTypography.labelSmall.copyWith(
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),

                  SizedBox(
                    width: double.infinity,
                    child: ShadiPrimaryButton(
                      key: const Key('review_submit_button'),
                      text: state.isSubmitting
                          ? 'Submitting…'
                          : 'Submit Review',
                      isLoading: state.isSubmitting,
                      onPressed: state.isSubmitting
                          ? null
                          : () async {
                              final ok = await controller.submitReview(
                                rating: overall,
                                feedback: feedbackController.text.trim(),
                                punctualityRating: punctuality,
                                groomingRating: grooming,
                              );
                              if (ok && sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Thank you! Your review helps other families choose with confidence.',
                                    ),
                                    backgroundColor: AppColors.verifiedEmerald,
                                  ),
                                );
                              }
                            },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}

class _RatingRow extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _RatingRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 170,
          child: Text(label, style: AppTypography.labelMedium),
        ),
        ...List.generate(5, (i) {
          final star = i + 1;
          return IconButton(
            key: Key('review_star_${label}_$star'),
            visualDensity: VisualDensity.compact,
            icon: Icon(
              star <= value ? Icons.star_rounded : Icons.star_outline_rounded,
              color: AppColors.warmGold,
              size: 26,
            ),
            onPressed: () => onChanged(star),
          );
        }),
      ],
    );
  }
}
