import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/shadi_error_view.dart';
import '../../../../core/widgets/shadi_loading_indicator.dart';
import '../../../../core/widgets/shadi_onboarding_steps.dart';
import '../../../../core/widgets/shadi_primary_button.dart';
import '../../../../core/widgets/shadi_status_badge.dart';
import 'controllers/partner_onboarding_controller.dart';
import 'partner_profile_form_screen.dart';
import 'partner_vehicle_form_screen.dart';
import 'partner_vehicle_pricing_screen.dart';
import 'widgets/partner_fleet_list.dart';
import 'widgets/partner_review_screen.dart';

/// Partner onboarding shell: hosts the guided stages
/// profile → fleet → vehicle → pricing → review → submitted.
///
/// Real backend only: every state change goes through
/// [PartnerOnboardingController] → repository → API client → NestJS.
class PartnerOnboardingScreen extends ConsumerWidget {
  const PartnerOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(partnerOnboardingProvider);
    final controller = ref.read(partnerOnboardingProvider.notifier);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // In-step back returns to the fleet, not out of the portal.
        if (state.stage != OnboardingStage.fleet &&
            state.stage != OnboardingStage.profile) {
          controller.backToFleet();
        } else {
          context.go(RoutePaths.customerHome);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(
          backgroundColor: AppColors.darkBurgundy,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Become a ShadiDriver Partner',
                style: AppTypography.titleMedium.copyWith(color: Colors.white),
              ),
              Text(
                _stageLabel(state),
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.champagneGold,
                ),
              ),
            ],
          ),
          actions: [
            if (state.profile != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: ShadiStatusBadge(
                    status: state.profile!.verificationStatus.wire,
                  ),
                ),
              ),
          ],
        ),
        // The full-screen loader guards ONLY the first boot, before we know
        // whether this account is already a partner. Every later refresh (the
        // fleet reload, a tariff refresh) leaves the current stage mounted and
        // renders its own inline progress — otherwise a stage that kicks off a
        // reload would be torn down by its own request and remount forever.
        body: state.isLoading && state.profile == null
            ? const ShadiLoadingIndicator(message: 'Loading your partner desk…')
            : state.roleBlocked
                ? const _PartnerRoleGate()
                : Column(
                    children: [
                      // REFERENCE STEP SYSTEM: progress with completed
                      // checks, the champagne active step, pending steps.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: ShadiOnboardingSteps(
                          steps: const [
                            ShadiOnboardingStep('Account & personal'),
                            ShadiOnboardingStep('Professional details'),
                            ShadiOnboardingStep('Add each car'),
                            ShadiOnboardingStep('Photos & documents'),
                            ShadiOnboardingStep('Service area'),
                            ShadiOnboardingStep('Pricing inputs'),
                            ShadiOnboardingStep('Review & verification'),
                          ],
                          currentStep: _stepIndex(state.stage),
                        ),
                      ),
                      Expanded(
                        child: switch (state.stage) {
                          OnboardingStage.profile => PartnerProfileFormScreen(
                              initial: state.profile,
                            ),
                          OnboardingStage.fleet => _FleetStage(state: state),
                          OnboardingStage.vehicleForm =>
                            PartnerVehicleFormScreen(
                              editing: state.editingVehicle,
                            ),
                          OnboardingStage.pricing =>
                            PartnerVehiclePricingScreen(
                              vehicle: state.editingVehicle,
                              existing: state.editingVehicleTariffs,
                            ),
                          OnboardingStage.review => PartnerReviewScreen(
                              profile: state.profile,
                              vehicle: state.editingVehicle,
                            ),
                        },
                      ),
                    ],
                  ),
      ),
    );
  }

  /// Maps the flow's stage onto the reference's 7-step ladder.
  static int _stepIndex(OnboardingStage stage) => switch (stage) {
        OnboardingStage.profile => 0,
        OnboardingStage.fleet => 2,
        OnboardingStage.vehicleForm => 2,
        OnboardingStage.pricing => 5,
        OnboardingStage.review => 6,
      };

  static String _stageLabel(PartnerOnboardingState state) => switch (state.stage) {
        OnboardingStage.profile =>
          state.profile == null ? 'Step 1 · Your details' : 'Step 2 · Edit details',
        OnboardingStage.fleet => 'Step 3 · My Fleet',
        OnboardingStage.vehicleForm =>
          state.editingVehicle == null
              ? 'Step 4 · Add Vehicle'
              : 'Step 4 · Edit Vehicle',
        OnboardingStage.pricing => 'Step 5 · Vehicle Pricing',
        OnboardingStage.review => 'Step 6 · Review & Submit',
      };
}

/// Shown when the signed-in account is not partner-capable.
///
/// The backend authorises `/api/v1/partner/*` for driver and fleetOwner only,
/// so a customer session is refused with 403 `ROLE_FORBIDDEN` before any fleet
/// work can happen. Rather than fail silently, the portal explains the gate and
/// states the honest next step.
class _PartnerRoleGate extends StatelessWidget {
  const _PartnerRoleGate();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.champagneGold.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.garage_rounded,
                size: 44,
                color: AppColors.darkBurgundy,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'A partner account is needed',
              textAlign: TextAlign.center,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Listing a fleet — vehicles, documents and per-vehicle pricing — is '
              'reserved for chauffeur and fleet-owner accounts.\n\n'
              'You are signed in as a customer, so ShadiDriver cannot open the '
              'partner desk for this session. Sign out and join as a Chauffeur to '
              'bring your fleet onto the platform.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 26),
            ShadiPrimaryButton(
              text: 'Back to My Account',
              icon: Icons.arrow_back_rounded,
              onPressed: () => context.go(RoutePaths.customerHome),
            ),
          ],
        ),
      ),
    );
  }
}

class _FleetStage extends ConsumerWidget {
  final PartnerOnboardingState state;

  const _FleetStage({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(partnerOnboardingProvider.notifier);

    // Fresh portal: no profile yet → collect professional details first.
    if (state.profile == null) {
      return const PartnerProfileFormScreen();
    }

    if (state.fleet == null) {
      // Load-on-enter without rebuild loops.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => controller.loadFleet(),
      );
      return const ShadiLoadingIndicator(message: 'Loading your fleet…');
    }

    final fleet = state.fleet!;
    final submitted = state.submittedForReview;

    return RefreshIndicator(
      onRefresh: controller.loadFleet,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (submitted) ...[
            const _SubmittedBanner(),
            const SizedBox(height: 16),
          ],
          if (state.errorMessage != null) ...[
            ShadiErrorView(
              message: state.errorMessage!,
              onRetry: () => controller.dismissError(),
            ),
            const SizedBox(height: 16),
          ],
          PartnerFleetList(fleet: fleet),
          const SizedBox(height: 20),
          ShadiPrimaryButton(
            text: '+ Add Vehicle',
            icon: Icons.add_rounded,
            onPressed: controller.startAddVehicle,
          ),
          const SizedBox(height: 12),
          ShadiPrimaryButton(
            text: fleet.total == 0
                ? 'Add a vehicle to continue'
                : 'Review & Submit for Verification',
            onPressed: fleet.total == 0 ? null : controller.goToReview,
            isLoading: state.isSaving,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SubmittedBanner extends StatelessWidget {
  const _SubmittedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.verifiedEmerald.withValues(alpha: 0.10),
        border: Border.all(color: AppColors.verifiedEmerald.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded, color: AppColors.verifiedEmerald),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Submitted — your fleet is now UNDER REVIEW. '
              'ShadiDriver operations will contact you. Verification is not '
              'complete yet.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
