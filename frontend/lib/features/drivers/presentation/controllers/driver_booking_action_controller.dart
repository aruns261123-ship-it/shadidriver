import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers/app_providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../bookings/domain/entities/booking_submission_result.dart';
import '../../../bookings/domain/repositories/booking_repository.dart';
import '../../domain/entities/driver_booking_offer.dart';
import '../../domain/entities/driver_decline_reason.dart';
import '../../domain/entities/driver_duty_status.dart';
import 'driver_dashboard_controller.dart';

/// State representation for driver booking actions (accept / decline).
@immutable
class DriverBookingActionState {
  final bool isActing;
  final bool isAccepted;
  final bool isDeclined;
  final bool isConflict;
  final String? errorMessage;
  final BookingSubmissionResult? acceptedResult;

  const DriverBookingActionState({
    this.isActing = false,
    this.isAccepted = false,
    this.isDeclined = false,
    this.isConflict = false,
    this.errorMessage,
    this.acceptedResult,
  });

  DriverBookingActionState copyWith({
    bool? isActing,
    bool? isAccepted,
    bool? isDeclined,
    bool? isConflict,
    String? errorMessage,
    BookingSubmissionResult? acceptedResult,
    bool clearError = false,
  }) {
    return DriverBookingActionState(
      isActing: isActing ?? this.isActing,
      isAccepted: isAccepted ?? this.isAccepted,
      isDeclined: isDeclined ?? this.isDeclined,
      isConflict: isConflict ?? this.isConflict,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      acceptedResult: acceptedResult ?? this.acceptedResult,
    );
  }
}

/// Controller managing chauffeur acceptance or decline with mandatory reason.
class DriverBookingActionController
    extends StateNotifier<DriverBookingActionState> {
  final Ref _ref;
  final BookingRepository bookingRepository;
  final String driverId;

  DriverBookingActionController(
    this._ref, {
    required this.bookingRepository,
    required this.driverId,
  }) : super(const DriverBookingActionState());

  /// Accepts a ceremonial booking request.
  ///
  /// Protects against concurrent driver claims by checking for [ConflictFailure].
  /// On success the chauffeur's profile duty status is engaged to BUSY
  /// ("On Active Assignment") so dispatch stops queueing further offers.
  Future<bool> acceptOffer(String bookingId) async {
    if (state.isActing) return false;

    state = state.copyWith(isActing: true, clearError: true, isConflict: false);

    final result = await bookingRepository.acceptBooking(
      bookingId: bookingId,
      driverId: driverId,
    );

    return result.fold(
      (failure) {
        if (!mounted) return false; // disposed mid-flight (e.g. screen popped)
        final isConflict = failure is ConflictFailure;
        state = state.copyWith(
          isActing: false,
          isConflict: isConflict,
          errorMessage: failure.message,
        );
        return false;
      },
      (acceptedResult) {
        if (!mounted) return false; // disposed mid-flight (e.g. screen popped)
        state = state.copyWith(
          isActing: false,
          isAccepted: true,
          acceptedResult: acceptedResult,
          clearError: true,
        );
        _engageDuty();
        return true;
      },
    );
  }

  /// Engages the chauffeur's duty status to BUSY after a successful acceptance
  /// and refreshes every live duty surface (profile badge, dashboard chips).
  Future<void> _engageDuty() async {
    try {
      final driverRepo = _ref.read(driverRepositoryProvider);
      await driverRepo.updateDutyStatus(
        driverId: driverId,
        status: DriverDutyStatus.busy,
      );
      _ref.invalidate(driverDutyStatusProvider(driverId));
    } catch (_) {
      // Duty engagement is best-effort; acceptance must never fail because of it.
    }
  }

  /// Declines a ceremonial booking request with mandatory operational reason.
  Future<bool> declineOffer(
    String bookingId,
    DriverDeclineReason reason,
  ) async {
    if (state.isActing) return false;

    state = state.copyWith(isActing: true, clearError: true);

    final result = await bookingRepository.declineBooking(
      bookingId: bookingId,
      driverId: driverId,
      reason: reason,
    );

    return result.fold(
      (failure) {
        if (!mounted) return false; // disposed mid-flight (e.g. screen popped)
        state = state.copyWith(isActing: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        if (!mounted) return false; // disposed mid-flight (e.g. screen popped)
        state = state.copyWith(
          isActing: false,
          isDeclined: true,
          clearError: true,
        );
        return true;
      },
    );
  }
}

/// Provider family for fetching detailed offer for a driver.
final driverBookingOfferDetailsProvider =
    FutureProvider.family<DriverBookingOffer, String>((ref, bookingId) async {
      final repo = ref.watch(bookingRepositoryProvider);
      final pricingPolicy = ref.watch(bookingPricingPolicyProvider);
      final driverId = ref.watch(currentDriverIdProvider);

      final result = await repo.getDriverBookingDetails(
        bookingId: bookingId,
        driverId: driverId,
      );
      return result.fold(
        (failure) => throw failure,
        (submission) => DriverBookingOffer.fromBookingSubmissionResult(
          submission,
          pricingPolicy,
        ),
      );
    });

/// Provider for [DriverBookingActionController].
final driverBookingActionControllerProvider =
    StateNotifierProvider.autoDispose<
      DriverBookingActionController,
      DriverBookingActionState
    >((ref) {
      final repo = ref.watch(bookingRepositoryProvider);
      final driverId = ref.watch(currentDriverIdProvider);

      return DriverBookingActionController(
        ref,
        bookingRepository: repo,
        driverId: driverId,
      );
    });
