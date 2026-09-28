import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers/partner_providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/partner_profile.dart';
import '../../domain/entities/partner_vehicle.dart';
import '../../domain/repositories/partner_repository.dart';

/// Where the partner is in the guided onboarding journey.
enum OnboardingStage {
  profile, // steps 1–3: account done (OTP), professional details
  fleet, // step 4: my fleet
  vehicleForm, // steps 5–8: add/edit a vehicle + photos + docs
  pricing, // step 8: per-vehicle tariff
  review, // step 9: final review + submit
}

/// Onboarding UI state.
class PartnerOnboardingState {
  final OnboardingStage stage;
  final PartnerProfile? profile;
  final PartnerFleet? fleet;

  /// The vehicle currently being added/edited (step 5–8 working set).
  final PartnerVehicle? editingVehicle;
  final List<VehicleTariff> editingVehicleTariffs;

  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  /// Set right after a successful submit-for-verification.
  final bool submittedForReview;

  /// TRUE when the signed-in identity is not a partner-capable role.
  ///
  /// The backend gates every `/api/v1/partner/*` route to driver/fleetOwner
  /// (403 `ROLE_FORBIDDEN`), so a customer-role session cannot list a fleet at
  /// all. This is a *gate*, not a failed request: the portal renders an
  /// explanation plus the honest next step instead of a raw error banner.
  final bool roleBlocked;

  const PartnerOnboardingState({
    this.stage = OnboardingStage.profile,
    this.profile,
    this.fleet,
    this.editingVehicle,
    this.editingVehicleTariffs = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.submittedForReview = false,
    this.roleBlocked = false,
  });

  /// Profile step gate: enough to register (backend requires company + city).
  bool get canSaveProfile =>
      (profile?.companyName.isNotEmpty ?? false) &&
      (profile?.baseCity?.isNotEmpty ?? false);

  PartnerOnboardingState copyWith({
    OnboardingStage? stage,
    PartnerProfile? profile,
    PartnerFleet? fleet,
    PartnerVehicle? editingVehicle,
    bool clearEditingVehicle = false,
    List<VehicleTariff>? editingVehicleTariffs,
    bool? isLoading,
    bool? isSaving,
    Object? errorMessage = _unset,
    bool? submittedForReview,
    bool? roleBlocked,
  }) =>
      PartnerOnboardingState(
        stage: stage ?? this.stage,
        profile: profile ?? this.profile,
        fleet: fleet ?? this.fleet,
        editingVehicle:
            clearEditingVehicle ? null : (editingVehicle ?? this.editingVehicle),
        editingVehicleTariffs: editingVehicleTariffs ?? this.editingVehicleTariffs,
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
        errorMessage:
            errorMessage == _unset ? this.errorMessage : errorMessage as String?,
        submittedForReview: submittedForReview ?? this.submittedForReview,
        roleBlocked: roleBlocked ?? this.roleBlocked,
      );

  static const Object _unset = Object();
}

/// Drives the partner onboarding flow through the real backend.
class PartnerOnboardingController extends Notifier<PartnerOnboardingState> {
  PartnerRepository get _repo => ref.read(partnerRepositoryProvider);

  @override
  PartnerOnboardingState build() {
    // Reload the profile from the server whenever the signed-in identity
    // changes (login → partner portal; sign-out → state reset).
    Future.microtask(() => refreshProfile());
    return const PartnerOnboardingState();
  }

  Future<void> refreshProfile() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await _repo.getProfile();
    result.when(
      success: (profile) => state = state.copyWith(
        isLoading: false,
        profile: profile,
        roleBlocked: false,
        // An already-registered partner lands directly on their fleet.
        stage: OnboardingStage.fleet,
      ),
      failure: (failure) {
        // 403 ROLE_FORBIDDEN: a customer-role session can never list a fleet.
        // Degrade to an explained role gate rather than a bare error banner.
        if (failure is ForbiddenFailure) {
          state = state.copyWith(
            isLoading: false,
            roleBlocked: true,
            errorMessage: null,
          );
          return;
        }
        // 404 NOT_FOUND: "No partner profile for this account" is the
        // EXPECTED first-run state for a new partner — that is the signal to
        // collect their details, not a failure to report.
        if (failure is NotFoundFailure) {
          state = state.copyWith(
            isLoading: false,
            profile: null,
            roleBlocked: false,
            stage: OnboardingStage.profile,
            errorMessage: null,
          );
          return;
        }
        state = state.copyWith(
          isLoading: false,
          roleBlocked: false,
          errorMessage: failure.message,
        );
      },
    );
  }

  /// Steps 1–3: create (idempotent) or update the partner profile.
  Future<bool> saveProfile(PartnerRegistrationDraft draft) async {
    state = state.copyWith(isSaving: true, errorMessage: null);
    final existing = state.profile;
    final result = existing == null
        ? await _repo.register(draft)
        : await _repo.updateProfile(draft);
    var saved = false;
    result.when(
      success: (profile) {
        saved = true;
        state = state.copyWith(
          isSaving: false,
          profile: profile,
          stage: OnboardingStage.fleet,
        );
      },
      failure: (failure) => state = state.copyWith(
        isSaving: false,
        errorMessage: failure.message,
      ),
    );
    return saved;
  }

  Future<void> loadFleet() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await _repo.listFleet();
    result.when(
      success: (fleet) => state = state.copyWith(isLoading: false, fleet: fleet),
      failure: (failure) =>
          state = state.copyWith(isLoading: false, errorMessage: failure.message),
    );
  }

  void startAddVehicle() {
    state = state.copyWith(
      editingVehicle: null,
      clearEditingVehicle: true,
      editingVehicleTariffs: const [],
      stage: OnboardingStage.vehicleForm,
      errorMessage: null,
    );
  }

  void startEditVehicle(PartnerVehicle vehicle) {
    state = state.copyWith(
      editingVehicle: vehicle,
      editingVehicleTariffs: const [],
      stage: OnboardingStage.vehicleForm,
      errorMessage: null,
    );
    unawaited(loadTariffs(vehicle.id));
  }

  void backToFleet() {
    state = state.copyWith(stage: OnboardingStage.fleet, errorMessage: null);
    unawaited(loadFleet());
  }

  /// Step 9 entry: open the final review (submission happens there).
  void goToReview() {
    state = state.copyWith(stage: OnboardingStage.review, errorMessage: null);
  }

  /// Steps 5–8: create or update the working vehicle through the backend.
  Future<bool> saveVehicle({
    PartnerVehicleDraft? newVehicle,
    PartnerVehicleEditDraft? edits,
  }) async {
    final editing = state.editingVehicle;
    state = state.copyWith(isSaving: true, errorMessage: null);
    final Result<PartnerVehicle> result;
    if (editing == null) {
      if (newVehicle == null) {
        state = state.copyWith(isSaving: false);
        return false;
      }
      result = await _repo.addVehicle(newVehicle);
    } else {
      result = await _repo.updateVehicle(editing.id, edits ?? const PartnerVehicleEditDraft());
    }
    var saved = false;
    result.when(
      success: (vehicle) {
        saved = true;
        state = state.copyWith(
          isSaving: false,
          editingVehicle: vehicle,
          stage: OnboardingStage.pricing,
        );
      },
      failure: (failure) => state = state.copyWith(
        isSaving: false,
        errorMessage: failure.message,
      ),
    );
    return saved;
  }

  Future<void> loadTariffs(String vehicleId) async {
    final result = await _repo.listTariffs(vehicleId);
    result.when(
      success: (tariffs) =>
          state = state.copyWith(editingVehicleTariffs: tariffs),
      failure: (failure) => state = state.copyWith(errorMessage: failure.message),
    );
  }

  /// Step 8: submit the tariff (server owns status → PENDING_REVIEW).
  Future<bool> submitTariff(VehicleTariffDraft draft) async {
    final vehicle = state.editingVehicle;
    if (vehicle == null) return false;
    state = state.copyWith(isSaving: true, errorMessage: null);
    final result = await _repo.submitTariff(vehicle.id, draft);
    var saved = false;
    result.when(
      success: (tariff) {
        saved = true;
        state = state.copyWith(
          isSaving: false,
          editingVehicleTariffs: [
            tariff,
            ...state.editingVehicleTariffs,
          ],
          stage: OnboardingStage.review,
        );
      },
      failure: (failure) => state = state.copyWith(
        isSaving: false,
        errorMessage: failure.message,
      ),
    );
    return saved;
  }

  /// Step 9: submit partner + fleet for verification.
  Future<bool> submitForVerification() async {
    state = state.copyWith(isSaving: true, errorMessage: null);
    final result = await _repo.submitForVerification();
    var ok = false;
    result.when(
      success: (profile) {
        ok = true;
        state = state.copyWith(
          isSaving: false,
          profile: profile,
          submittedForReview: true,
          stage: OnboardingStage.fleet,
        );
      },
      failure: (failure) => state = state.copyWith(
        isSaving: false,
        errorMessage: failure.message,
      ),
    );
    return ok;
  }

  void dismissError() =>
      state = state.copyWith(errorMessage: null);
}

/// keepAlive: the partner portal is a workspace, not a transient screen.
final partnerOnboardingProvider =
    NotifierProvider<PartnerOnboardingController, PartnerOnboardingState>(
  PartnerOnboardingController.new,
);
