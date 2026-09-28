import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/shadi_card.dart';
import '../../../../core/widgets/shadi_error_view.dart';
import '../../../../core/widgets/shadi_primary_button.dart';
import '../../../../core/widgets/shadi_status_badge.dart';
import '../../domain/entities/partner_profile.dart';
import '../../domain/entities/partner_vehicle.dart';
import '../controllers/partner_onboarding_controller.dart';

/// Step 6: final review before submitting for verification. Shows exactly
/// what operations will inspect — nothing more, nothing invented.
class PartnerReviewScreen extends ConsumerStatefulWidget {
  final PartnerProfile? profile;
  final PartnerVehicle? vehicle;

  const PartnerReviewScreen({
    super.key,
    required this.profile,
    required this.vehicle,
  });

  @override
  ConsumerState<PartnerReviewScreen> createState() =>
      _PartnerReviewScreenState();
}

class _PartnerReviewScreenState extends ConsumerState<PartnerReviewScreen> {
  @override
  void initState() {
    super.initState();
    // The fleet section must reflect the server truth when the review opens,
    // not whatever happened to be cached in the controller state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(partnerOnboardingProvider.notifier).loadFleet();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(partnerOnboardingProvider);
    final profile = widget.profile;
    final vehicle = widget.vehicle;
    final fleet = state.fleet;
    final p = profile;
    final selectedVehicle = vehicle;
    if (p == null) {
      return const Center(child: Text('Save your profile first.'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Submission failures (e.g. backend "add at least one vehicle")
        // surface here, on the screen where the tap happened.
        if (state.errorMessage != null) ...[
          ShadiErrorView(
            message: state.errorMessage!,
            onRetry: () =>
                ref.read(partnerOnboardingProvider.notifier).dismissError(),
          ),
          const SizedBox(height: 16),
        ],
        Text('Review & Submit', style: AppTypography.titleLarge),
        const SizedBox(height: 4),
        Text(
          'ShadiDriver operations verifies partners and vehicles separately. '
          'You will be contacted on your registered number.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 20),

        // ---------------------------------------------------- partner details
        ShadiCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text('Partner Details',
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w800,
                      )),
                ),
                ShadiStatusBadge(status: p.verificationStatus.wire),
              ]),
              const SizedBox(height: 10),
              _kv('Company', p.companyName),
              if (p.contactName != null) _kv('Contact', p.contactName!),
              _kv('Base city', p.baseCity ?? '—'),
              if (p.serviceCities.isNotEmpty)
                _kv('Service cities', p.serviceCities.join(', ')),
              _kv('Languages', p.languagesSpoken.join(', ')),
              _kv('Experience', '${p.experienceYears} years'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ------------------------------------------------------------- fleet
        ShadiCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fleet', style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w800,
              )),
              const SizedBox(height: 10),
              if (fleet == null || fleet.items.isEmpty)
                const Text('No vehicles yet.')
              else
                for (final v in fleet.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${v.displayName ?? v.fleetCode} · '
                            '${v.maskedRegistration}',
                            style: AppTypography.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ShadiStatusBadge(status: v.verificationStatus.wire),
                      ],
                    ),
                  ),
              if (selectedVehicle != null)
                _pricingSubmittedLine(selectedVehicle),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ShadiPrimaryButton(
          text: 'Submit for Verification',
          onPressed:
              state.isSaving ? null : () => ref
                  .read(partnerOnboardingProvider.notifier)
                  .submitForVerification(),
          isLoading: state.isSaving,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  /// Local promotion: `vehicle` is a nullable field, so a helper keeps the
  /// null-check meaningful for the display-name fallback.
  Widget _pricingSubmittedLine(PartnerVehicle v) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          'Pricing submitted for: ${v.displayName ?? v.fleetCode}',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.verifiedEmerald,
          ),
        ),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(k, style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondaryLight,
              )),
            ),
            Expanded(
              child: Text(v, style: AppTypography.bodyMedium),
            ),
          ],
        ),
      );
}
