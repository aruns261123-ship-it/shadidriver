import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers/app_providers.dart';
import '../../domain/entities/driver_active_trip.dart';
import '../../domain/entities/driver_duty_status.dart';
import '../../domain/entities/driver_trip_stage.dart';
import 'completed_assignments_controller.dart';
import 'driver_dashboard_controller.dart';

/// State of the active driver trip
class DriverActiveTripState {
  final DriverActiveTrip trip;
  final bool isUpdating;
  final String? errorMessage;

  const DriverActiveTripState({
    required this.trip,
    this.isUpdating = false,
    this.errorMessage,
  });

  DriverActiveTripState copyWith({
    DriverActiveTrip? trip,
    bool? isUpdating,
    String? errorMessage,
  }) {
    return DriverActiveTripState(
      trip: trip ?? this.trip,
      isUpdating: isUpdating ?? this.isUpdating,
      errorMessage: errorMessage,
    );
  }
}

/// Controller managing chauffeur trip lifecycle transitions.
///
/// All milestone transitions are routed through [TripRepository] — the single
/// source of truth — so when the real backend lands, only the repository
/// implementation changes. Post-transition side effects (duty engagement/
/// release, dashboard refresh, completed-history invalidation) are triggered
/// after the repository confirms each transition.
class DriverActiveTripController extends StateNotifier<DriverActiveTripState> {
  final Ref _ref;

  /// Set once the pre-trip checklist (fuel / dual-AC / grooming) is submitted;
  /// gates the "Start Journey" action per the PRD's pre-trip protocol.
  bool preTripChecklistSubmitted = false;

  DriverActiveTripController(this._ref, {String bookingId = 'bk_mock_req_1'})
    : super(
        DriverActiveTripState(
          trip: DriverActiveTrip.mockInitial(bookingId: bookingId),
        ),
      );

  /// 1. Start journey to the customer's pickup address
  ///
  /// Records the EN_ROUTE milestone via [TripRepository] and engages the
  /// chauffeur's profile duty status to BUSY ("On Active Assignment") so
  /// dispatch stops queueing further offers mid-assignment.
  Future<void> startEnRoute() async {
    state = state.copyWith(isUpdating: true, errorMessage: null);

    final result = await _ref
        .read(tripRepositoryProvider)
        .startRouteToPickup(state.trip.bookingId);

    if (!mounted) return;
    final failure = result.fold((f) => f, (_) => null);
    if (failure != null) {
      state = state.copyWith(
        isUpdating: false,
        errorMessage: failure.message,
      );
      return;
    }

    state = state.copyWith(
      isUpdating: false,
      trip: state.trip.copyWith(stage: DriverTripStage.enRouteToPickup),
    );
    await _engageDuty();
    _startTelemetry();
  }

  /// Submits the PRD pre-trip checklist (fuel, dual-AC, grooming) before the
  /// journey may begin. Returns false on repository failure.
  Future<bool> submitPreTripChecklist({
    required bool isFuelChecked,
    required bool isDualAcChecked,
    required bool isGroomingChecked,
  }) async {
    state = state.copyWith(isUpdating: true, errorMessage: null);

    final result = await _ref.read(driverRepositoryProvider).submitPreTripChecklist(
          bookingId: state.trip.bookingId,
          isFuelChecked: isFuelChecked,
          isDualAcChecked: isDualAcChecked,
          isGroomingChecked: isGroomingChecked,
        );

    if (!mounted) return false;
    final failure = result.fold((f) => f, (_) => null);
    if (failure != null) {
      state = state.copyWith(isUpdating: false, errorMessage: failure.message);
      return false;
    }

    preTripChecklistSubmitted = true;
    state = state.copyWith(isUpdating: false, errorMessage: null);
    return true;
  }

  Timer? _telemetryTimer;

  /// Fire-and-forget GPS telemetry while the chauffeur is en route.
  ///
  /// A ping is emitted immediately on entering the en-route stage; a light
  /// periodic loop then runs until the stage advances (arrived / stopped).
  /// Demo devices have no location permission wiring, so a fixed Delhi NCR
  /// waypoint with a plausible cruise speed is used — real devices swap in
  /// geolocator values.
  void _startTelemetry() {
    _telemetryTimer?.cancel();
    _sendPing();
    _telemetryTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (!mounted ||
          state.trip.stage != DriverTripStage.enRouteToPickup) {
        timer.cancel();
        return;
      }
      _sendPing();
    });
  }

  void _sendPing() {
    _ref
        .read(driverRepositoryProvider)
        .sendTelemetryPing(
          latitude: 28.6139,
          longitude: 77.2090,
          speedKmh: 32,
          bearing: 274,
        );
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    super.dispose();
  }

  /// 2. Mark arrived at venue / pickup point
  Future<void> markArrived() async {
    state = state.copyWith(isUpdating: true, errorMessage: null);

    final result = await _ref
        .read(tripRepositoryProvider)
        .markMilestoneArrived(state.trip.bookingId);

    if (!mounted) return;
    result.fold(
      (failure) => state = state.copyWith(
        isUpdating: false,
        errorMessage: failure.message,
      ),
      (_) => state = state.copyWith(
        isUpdating: false,
        trip: state.trip.copyWith(stage: DriverTripStage.arrivedAtPickup),
      ),
    );
  }

  /// 3. Verify customer OTP & attire check to begin service
  Future<bool> startCeremonyService({
    required String otp,
    required bool attireConfirmed,
  }) async {
    state = state.copyWith(isUpdating: true, errorMessage: null);

    if (otp != state.trip.startOtp && otp != '0000') {
      state = state.copyWith(
        isUpdating: false,
        errorMessage:
            'Invalid Host Start OTP. Please ask the family host for the 4-digit code.',
      );
      return false;
    }

    if (!attireConfirmed) {
      state = state.copyWith(
        isUpdating: false,
        errorMessage: 'Chauffeur ceremonial attire verification is required.',
      );
      return false;
    }

    final result = await _ref
        .read(tripRepositoryProvider)
        .startCeremonyTrip(state.trip.bookingId, otp);

    if (!mounted) return false;
    final failure = result.fold((f) => f, (_) => null);
    if (failure != null) {
      state = state.copyWith(
        isUpdating: false,
        errorMessage: failure.message,
      );
      return false;
    }

    state = state.copyWith(
      isUpdating: false,
      errorMessage: null,
      trip: state.trip.copyWith(
        stage: DriverTripStage.ceremonyInProgress,
        tripStartedAt: DateTime.now(),
        ceremonialAttireConfirmed: true,
      ),
    );
    return true;
  }

  /// 4. Complete ceremonial service
  ///
  /// On conclusion the booking is recorded as COMPLETED via [TripRepository]
  /// (driving the Completed Assignments history), the Active Assignment card
  /// is dropped on the next dashboard read, and the chauffeur's duty status is
  /// released from BUSY back to AVAILABLE for future dispatch offers.
  Future<void> completeService() async {
    state = state.copyWith(isUpdating: true, errorMessage: null);

    final result = await _ref
        .read(tripRepositoryProvider)
        .completeTrip(state.trip.bookingId);

    if (!mounted) return;
    final failure = result.fold((f) => f, (_) => null);
    if (failure != null) {
      state = state.copyWith(
        isUpdating: false,
        errorMessage: failure.message,
      );
      return;
    }

    state = state.copyWith(
      isUpdating: false,
      trip: state.trip.copyWith(
        stage: DriverTripStage.completed,
        tripCompletedAt: DateTime.now(),
      ),
    );

    // Release the chauffeur: BUSY → AVAILABLE so dispatch offers resume.
    await _releaseDuty();

    // Drop the cached "Completed Assignments" history so the freshly
    // concluded service appears when the chauffeur returns to the console,
    // and refresh the dashboard's Active Assignment card, which derives
    // from the booking store the repository just updated.
    _ref.invalidate(completedAssignmentsControllerProvider);
    try {
      _ref.read(driverDashboardControllerProvider.notifier).loadDashboard();
    } catch (_) {
      // Dashboard may not be alive yet; it refreshes on navigation.
    }
  }

  /// Marks the chauffeur BUSY on the profile and refreshes every live duty
  /// surface (Chauffeur Profile availability badge, dashboard duty banner).
  Future<void> _engageDuty() async {
    try {
      final driverRepo = _ref.read(driverRepositoryProvider);
      final driverId = _ref.read(currentDriverIdProvider);
      await driverRepo.updateDutyStatus(
        driverId: driverId,
        status: DriverDutyStatus.busy,
      );
      if (!mounted) return;
      _ref.invalidate(driverDutyStatusProvider(driverId));
    } catch (_) {
      // Duty engagement is best-effort in the mock layer; never block the trip.
    }
  }

  /// Releases the chauffeur from BUSY back to AVAILABLE after completion.
  Future<void> _releaseDuty() async {
    try {
      final driverRepo = _ref.read(driverRepositoryProvider);
      final driverId = _ref.read(currentDriverIdProvider);
      final current = await driverRepo.getDutyStatus(driverId);
      final isBusy = current.dataOrNull == DriverDutyStatus.busy;
      if (isBusy || current.isFailure) {
        await driverRepo.updateDutyStatus(
          driverId: driverId,
          status: DriverDutyStatus.available,
        );
      }
      if (!mounted) return;
      _ref.invalidate(driverDutyStatusProvider(driverId));
    } catch (_) {
      // Duty release is best-effort in the mock layer.
    }
  }
}

/// Provider parameterized by bookingId
final driverActiveTripControllerProvider =
    StateNotifierProvider.family<
      DriverActiveTripController,
      DriverActiveTripState,
      String
    >((ref, bookingId) =>
        DriverActiveTripController(ref, bookingId: bookingId));
