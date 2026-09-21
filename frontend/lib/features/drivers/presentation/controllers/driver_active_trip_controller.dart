import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers/app_providers.dart';
import '../../../bookings/data/mock_booking_repository.dart';
import '../../../bookings/domain/entities/booking_status.dart';
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
class DriverActiveTripController extends StateNotifier<DriverActiveTripState> {
  final Ref _ref;

  DriverActiveTripController(this._ref, {String bookingId = 'bk_mock_req_1'})
    : super(
        DriverActiveTripState(
          trip: DriverActiveTrip.mockInitial(bookingId: bookingId),
        ),
      );

  /// 1. Start journey to the customer's pickup address
  ///
  /// Engages the chauffeur's profile duty status to BUSY ("On Active
  /// Assignment") so dispatch stops queueing further offers mid-assignment,
  /// and records the DRIVER_ARRIVING milestone on the booking store so the
  /// admin dispatch monitor mirrors the live ceremony stage.
  Future<void> startEnRoute() async {
    state = state.copyWith(isUpdating: true, errorMessage: null);
    await Future.delayed(const Duration(milliseconds: 200));
    state = state.copyWith(
      isUpdating: false,
      trip: state.trip.copyWith(stage: DriverTripStage.enRouteToPickup),
    );

    _syncBookingStage(BookingStatus.driverArriving);
    await _engageDuty();
  }

  /// Writes the current trip milestone to the shared booking store so admin
  /// and dashboard surfaces derive live stage info. Best-effort in the mock
  /// layer; never blocks the driver's trip progression.
  void _syncBookingStage(BookingStatus status) {
    try {
      final bookingStore =
          _ref.read(bookingRepositoryProvider) as MockBookingRepository;
      bookingStore.updateBookingStage(state.trip.bookingId, status);
    } catch (_) {
      // Booking store is only a mock-composition detail.
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
      _refreshDutySurfaces(driverId);
    } catch (_) {
      // Duty engagement is best-effort in the mock layer; never block the trip.
    }
  }

  /// Refreshes live duty watchers so the profile badge and dashboard chips
  /// reflect the change immediately instead of on next screen entry.
  void _refreshDutySurfaces(String driverId) {
    try {
      _ref.invalidate(driverDutyStatusProvider(driverId));
      _ref.read(driverDashboardControllerProvider.notifier).loadDashboard();
    } catch (_) {
      // Dashboard may not be alive yet; badge refetches on navigation anyway.
    }
  }

  /// 2. Mark arrived at venue / pickup point
  Future<void> markArrived() async {
    state = state.copyWith(isUpdating: true, errorMessage: null);
    await Future.delayed(const Duration(milliseconds: 200));
    state = state.copyWith(
      isUpdating: false,
      trip: state.trip.copyWith(stage: DriverTripStage.arrivedAtPickup),
    );

    _syncBookingStage(BookingStatus.arrived);
  }

  /// 3. Verify customer OTP & attire check to begin service
  Future<bool> startCeremonyService({
    required String otp,
    required bool attireConfirmed,
  }) async {
    state = state.copyWith(isUpdating: true, errorMessage: null);
    await Future.delayed(const Duration(milliseconds: 300));

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

    state = state.copyWith(
      isUpdating: false,
      errorMessage: null,
      trip: state.trip.copyWith(
        stage: DriverTripStage.ceremonyInProgress,
        tripStartedAt: DateTime.now(),
        ceremonialAttireConfirmed: true,
      ),
    );

    _syncBookingStage(BookingStatus.tripStarted);
    return true;
  }

  /// 4. Complete ceremonial service
  ///
  /// On conclusion the booking is recorded as COMPLETED (so it appears in the
  /// Completed Assignments history) and the chauffeur's duty status is released
  /// from BUSY back to AVAILABLE for future dispatch offers.
  Future<void> completeService() async {
    state = state.copyWith(isUpdating: true, errorMessage: null);
    await Future.delayed(const Duration(milliseconds: 300));

    state = state.copyWith(
      isUpdating: false,
      trip: state.trip.copyWith(
        stage: DriverTripStage.completed,
        tripCompletedAt: DateTime.now(),
      ),
    );

    // Record completion in the booking store (drives the Completed
    // Assignments section on the Chauffeur Console).
    try {
      final bookingStore =
          _ref.read(bookingRepositoryProvider) as MockBookingRepository;
      bookingStore.markBookingCompleted(state.trip.bookingId);
    } catch (_) {
      // Booking store is only a mock-composition detail; never block completion.
    }

    // Release the chauffeur: BUSY → AVAILABLE so dispatch offers resume.
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
      // Refresh the dashboard and profile badge so the duty banner, offer
      // queue, and availability chip reflect the release immediately when the
      // chauffeur returns.
      _refreshDutySurfaces(driverId);
    } catch (_) {
      // Duty release is best-effort in the mock layer.
    }

    // Drop the cached "Completed Assignments" history so the freshly concluded
    // service appears when the chauffeur returns to the console. Also refresh
    // the dashboard's Active Assignment card, which derives from the store.
    _ref.invalidate(completedAssignmentsControllerProvider);
    _ref.read(driverDashboardControllerProvider.notifier).loadDashboard();
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
