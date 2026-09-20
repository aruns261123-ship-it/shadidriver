import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/driver_active_trip.dart';
import '../../domain/entities/driver_trip_stage.dart';

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
  DriverActiveTripController({String bookingId = 'bk_mock_req_1'})
    : super(
        DriverActiveTripState(
          trip: DriverActiveTrip.mockInitial(bookingId: bookingId),
        ),
      );

  /// 1. Start journey to the customer's pickup address
  Future<void> startEnRoute() async {
    state = state.copyWith(isUpdating: true, errorMessage: null);
    await Future.delayed(const Duration(milliseconds: 200));
    state = state.copyWith(
      isUpdating: false,
      trip: state.trip.copyWith(stage: DriverTripStage.enRouteToPickup),
    );
  }

  /// 2. Mark arrived at venue / pickup point
  Future<void> markArrived() async {
    state = state.copyWith(isUpdating: true, errorMessage: null);
    await Future.delayed(const Duration(milliseconds: 200));
    state = state.copyWith(
      isUpdating: false,
      trip: state.trip.copyWith(stage: DriverTripStage.arrivedAtPickup),
    );
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
    return true;
  }

  /// 4. Complete ceremonial service
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
  }
}

/// Provider parameterized by bookingId
final driverActiveTripControllerProvider =
    StateNotifierProvider.family<
      DriverActiveTripController,
      DriverActiveTripState,
      String
    >((ref, bookingId) => DriverActiveTripController(bookingId: bookingId));
