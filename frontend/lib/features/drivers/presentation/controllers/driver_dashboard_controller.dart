import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers/app_providers.dart';
import '../../../bookings/domain/policies/booking_pricing_policy.dart';
import '../../../bookings/domain/repositories/booking_repository.dart';
import '../../domain/entities/driver_booking_offer.dart';
import '../../domain/entities/driver_duty_status.dart';
import '../../domain/repositories/driver_repository.dart';

/// Provider exposing the current logged-in driver ID.
/// In production, this would be wired to the Auth/Session state.
final currentDriverIdProvider = Provider<String>((ref) => 'd1');

/// State representation for the Chauffeur / Driver Dashboard.
@immutable
class DriverDashboardState {
  final DriverDutyStatus dutyStatus;
  final List<DriverBookingOffer> offers;
  final bool isLoading;
  final String? errorMessage;

  const DriverDashboardState({
    this.dutyStatus = DriverDutyStatus.available,
    this.offers = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  bool get canReceiveOffers => dutyStatus.canReceiveOffers;
  bool get hasError => errorMessage != null;

  DriverDashboardState copyWith({
    DriverDutyStatus? dutyStatus,
    List<DriverBookingOffer>? offers,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DriverDashboardState(
      dutyStatus: dutyStatus ?? this.dutyStatus,
      offers: offers ?? this.offers,
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

    // 2. If available, fetch offers
    List<DriverBookingOffer> loadedOffers = [];
    String? fetchError;

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

    state = state.copyWith(
      dutyStatus: status,
      offers: loadedOffers,
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
final driverDashboardControllerProvider =
    StateNotifierProvider.autoDispose<
      DriverDashboardController,
      DriverDashboardState
    >((ref) {
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
