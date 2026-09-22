import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers/app_providers.dart';
import '../../../bookings/domain/policies/booking_pricing_policy.dart';
import '../../../bookings/domain/repositories/booking_repository.dart';
import '../../domain/entities/driver_active_trip.dart';
import '../../domain/entities/driver_booking_offer.dart';
import '../../domain/entities/driver_duty_status.dart';
import '../../domain/entities/driver_trip_stage.dart';
import '../../domain/repositories/driver_repository.dart';

/// Phone → roster-ID resolution for demo driver accounts.
///
/// The mock auth store issues sessions keyed by phone; this maps registered
/// driver accounts onto the chauffeur roster. Unauthenticated/dev-harness
/// sessions fall back to the primary demo chauffeur.
const _demoDriverAccounts = <String, String>{
  '9810000002': 'd1',
  '9876500002': 'd1',
};

/// Provider exposing the current logged-in driver ID, resolved from the auth
/// session's masked phone so the driver portal shows the logged-in chauffeur's
/// data. Falls back to the demo chauffeur when no session is active (tests,
/// dev harness).
final currentDriverIdProvider = Provider<String>((ref) {
  final session = ref.watch(activeSessionProvider);
  if (!session.isAuthenticated) return 'd1';
  // Masked format: "+91 XXXXX XXXXX" — recover the 10-digit local number.
  final digits = session.phone.replaceAll(RegExp(r'\D'), '');
  final local10 = digits.length > 10
      ? digits.substring(digits.length - 10)
      : digits;
  return _demoDriverAccounts[local10] ?? 'd1';
});

/// Live operational duty status for a chauffeur, shared between the Chauffeur
/// Console (duty chips) and the Chauffeur Profile (availability badge).
final driverDutyStatusProvider = FutureProvider.autoDispose
    .family<DriverDutyStatus, String>((ref, driverId) async {
      final driverRepo = ref.watch(driverRepositoryProvider);
      final result = await driverRepo.getDutyStatus(driverId);
      return result.fold(
        (failure) => DriverDutyStatus.available,
        (status) => status,
      );
    });

/// State representation for the Chauffeur / Driver Dashboard.
@immutable
class DriverDashboardState {
  final DriverDutyStatus dutyStatus;
  final List<DriverBookingOffer> offers;

  /// The chauffeur's live (accepted, not completed) assignment, if any.
  ///
  /// Derived from the booking store — not a hardcoded placeholder — so it
  /// disappears the moment the service is concluded and COMPLETED.
  final DriverActiveTrip? activeAssignment;
  final bool isLoading;
  final String? errorMessage;

  const DriverDashboardState({
    this.dutyStatus = DriverDutyStatus.available,
    this.offers = const [],
    this.activeAssignment,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get canReceiveOffers => dutyStatus.canReceiveOffers;
  bool get hasError => errorMessage != null;
  bool get hasActiveAssignment => activeAssignment != null;

  DriverDashboardState copyWith({
    DriverDutyStatus? dutyStatus,
    List<DriverBookingOffer>? offers,
    DriverActiveTrip? activeAssignment,
    bool clearActiveAssignment = false,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DriverDashboardState(
      dutyStatus: dutyStatus ?? this.dutyStatus,
      offers: offers ?? this.offers,
      activeAssignment: clearActiveAssignment
          ? null
          : (activeAssignment ?? this.activeAssignment),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Controller managing driver duty status and available booking offers.
class DriverDashboardController extends StateNotifier<DriverDashboardState> {
  final DriverRepository driverRepository;
  final BookingRepository bookingRepository;
  final BookingPricingPolicy pricingPolicy;
  final String driverId;

  DriverDashboardController({
    required this.driverRepository,
    required this.bookingRepository,
    required this.pricingPolicy,
    required this.driverId,
  }) : super(const DriverDashboardState(isLoading: true)) {
    loadDashboard();
  }

  /// Loads initial duty status and available requests.
  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, clearError: true);

    // 1. Fetch duty status
    final statusResult = await driverRepository.getDutyStatus(driverId);
    final status = statusResult.fold(
      (failure) => DriverDutyStatus.available,
      (currentStatus) => currentStatus,
    );

    if (!mounted) return; // disposed mid-flight (e.g. cross-screen refresh)

    String? fetchError;

    // 2. Fetch the chauffeur's live assignment (accepted, not completed).
    //    Kept separate from offers so the Active Assignment card reflects real
    //    booking-store state and disappears on completion.
    final activeResult = await bookingRepository.getDriverActiveAssignments(
      driverId: driverId,
    );
    DriverActiveTrip? activeAssignment;
    activeResult.fold(
      (failure) => fetchError = failure.message,
      (list) => activeAssignment = list.isEmpty
          ? null
          : DriverActiveTrip.fromBookingResult(
              list.first,
              stage: DriverTripStage.enRouteToPickup,
            ),
    );

    if (!mounted) return; // disposed mid-flight (e.g. cross-screen refresh)

    // 3. If available, fetch offers
    List<DriverBookingOffer> loadedOffers = [];

    if (status.canReceiveOffers) {
      final offersResult = await bookingRepository.getDriverBookingRequests(
        driverId: driverId,
      );
      offersResult.fold(
        (failure) => fetchError = failure.message,
        (list) => loadedOffers = list
            .map(
              (res) => DriverBookingOffer.fromBookingSubmissionResult(
                res,
                pricingPolicy,
              ),
            )
            .toList(),
      );
    }

    if (!mounted) return;

    state = state.copyWith(
      dutyStatus: status,
      offers: loadedOffers,
      activeAssignment: activeAssignment,
      // A reload must be authoritative: when the store reports no live
      // assignment (service concluded), the stale card is dropped instead of
      // being preserved by copyWith's `??` fallback.
      clearActiveAssignment: activeAssignment == null,
      isLoading: false,
      errorMessage: fetchError,
    );
  }

  /// Updates driver operational duty status.
  Future<bool> setDutyStatus(DriverDutyStatus newStatus) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await driverRepository.updateDutyStatus(
      driverId: driverId,
      status: newStatus,
    );
    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
      (_) async {
        List<DriverBookingOffer> newOffers = [];
        String? fetchError;

        if (newStatus.canReceiveOffers) {
          final offersResult = await bookingRepository.getDriverBookingRequests(
            driverId: driverId,
          );
          offersResult.fold(
            (failure) => fetchError = failure.message,
            (list) => newOffers = list
                .map(
                  (res) => DriverBookingOffer.fromBookingSubmissionResult(
                    res,
                    pricingPolicy,
                  ),
                )
                .toList(),
          );
        }

        state = state.copyWith(
          dutyStatus: newStatus,
          offers: newOffers,
          // Duty transitions preserve the current assignment view; the card
          // is refreshed by loadDashboard's authoritative store read.
          isLoading: false,
          errorMessage: fetchError,
        );
        return true;
      },
    );
  }

  /// Refreshes incoming booking offers from the dispatch queue.
  Future<void> refreshOffers() async {
    if (!state.canReceiveOffers) return;

    final offersResult = await bookingRepository.getDriverBookingRequests(
      driverId: driverId,
    );
    offersResult.fold(
      (failure) {
        state = state.copyWith(errorMessage: failure.message);
      },
      (list) {
        final newOffers = list
            .map(
              (res) => DriverBookingOffer.fromBookingSubmissionResult(
                res,
                pricingPolicy,
              ),
            )
            .toList();
        state = state.copyWith(offers: newOffers, clearError: true);
      },
    );
  }
}

/// Riverpod provider for [DriverDashboardController].
///
/// Kept alive (not autoDispose) so trip completions made in the Active Trip
/// Console are reflected when the chauffeur returns to this dashboard.
final driverDashboardControllerProvider =
    StateNotifierProvider<DriverDashboardController, DriverDashboardState>((
      ref,
    ) {
      final driverRepo = ref.watch(driverRepositoryProvider);
      final bookingRepo = ref.watch(bookingRepositoryProvider);
      final pricingPolicy = ref.watch(bookingPricingPolicyProvider);
      final driverId = ref.watch(currentDriverIdProvider);

      return DriverDashboardController(
        driverRepository: driverRepo,
        bookingRepository: bookingRepo,
        pricingPolicy: pricingPolicy,
        driverId: driverId,
      );
    });
