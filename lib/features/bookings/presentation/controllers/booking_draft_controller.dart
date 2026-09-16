import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers/app_providers.dart';
import '../../../vehicles/domain/entities/vehicle_details.dart';
import '../../domain/entities/booking_draft.dart';
import '../../domain/policies/booking_pricing_policy.dart';
import '../../domain/repositories/booking_repository.dart';
import '../../domain/services/route_distance_service.dart';

/// State object representing the active draft creation flow.
class BookingDraftState {
  final BookingDraft draft;
  final int activeStep;
  final bool isLoading;
  final String? errorMessage;
  final BookingDraft? savedDraft;

  const BookingDraftState({
    required this.draft,
    this.activeStep = 0,
    this.isLoading = false,
    this.errorMessage,
    this.savedDraft,
  });

  bool get isSaved => savedDraft != null;

  BookingDraftState copyWith({
    BookingDraft? draft,
    int? activeStep,
    bool? isLoading,
    String? errorMessage,
    BookingDraft? savedDraft,
    bool clearError = false,
  }) {
    return BookingDraftState(
      draft: draft ?? this.draft,
      activeStep: activeStep ?? this.activeStep,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      savedDraft: savedDraft ?? this.savedDraft,
    );
  }
}

/// Controller managing customer booking draft updates, step transitions, and persistence.
class BookingDraftController extends StateNotifier<BookingDraftState> {
  final BookingRepository bookingRepository;
  final BookingPricingPolicy pricingPolicy;
  final RouteDistanceService? routeDistanceService;

  BookingDraftController({
    required this.bookingRepository,
    required this.pricingPolicy,
    this.routeDistanceService,
    required VehicleDetails vehicle,
  }) : super(
         _createInitialState(vehicle: vehicle, pricingPolicy: pricingPolicy),
       );

  static BookingDraftState _createInitialState({
    required VehicleDetails vehicle,
    required BookingPricingPolicy pricingPolicy,
  }) {
    const defaultDuration = 8;
    final pricing = pricingPolicy.calculatePricing(
      basePricePaise: vehicle.pricing.basePriceCents,
      durationHours: defaultDuration,
    );

    return BookingDraftState(
      draft: BookingDraft.initial(
        vehicleId: vehicle.id,
        vehicleName: '${vehicle.make} ${vehicle.model}',
        vehicleClass: vehicle.vehicleClass,
        chauffeurId: vehicle.chauffeurId,
        basePricePaise: pricing.basePricePaise,
        estimatedTotalPaise: pricing.estimatedTotalPaise,
        advanceTokenPaise: pricing.advanceTokenPaise,
        advanceTokenLabel: pricing.advanceTokenLabel,
        durationHours: defaultDuration,
      ),
    );
  }

  /// Updates Section 1: Event & Ceremony
  void updateCeremony({
    required String ceremonyType,
    required String attire,
    String instructions = '',
  }) {
    state = state.copyWith(
      draft: state.draft.copyWith(
        ceremonyType: ceremonyType,
        ceremonialAttire: attire,
        specialInstructions: instructions,
      ),
      clearError: true,
    );
  }

  /// Updates Section 2 with explicit start and end DateTimes (supporting overnight bookings).
  void updateServiceTiming({
    required DateTime startDateTime,
    required DateTime endDateTime,
  }) {
    final diffHours = endDateTime.difference(startDateTime).inHours;
    final durationHours = diffHours > 0 ? diffHours : 1;

    final pricing = pricingPolicy.calculatePricing(
      basePricePaise: state.draft.basePricePaise,
      durationHours: durationHours,
    );

    state = state.copyWith(
      draft: state.draft.copyWith(
        serviceStartDateTime: startDateTime,
        serviceEndDateTime: endDateTime,
        estimatedTotalPaise: pricing.estimatedTotalPaise,
        advanceTokenPaise: pricing.advanceTokenPaise,
        advanceTokenLabel: pricing.advanceTokenLabel,
      ),
      clearError: true,
    );
  }

  /// Backwards-compatible Section 2 updater using date, time, and hours.
  void updateDateTime({
    required DateTime date,
    required TimeOfDay startTime,
    required int durationHours,
  }) {
    final start = DateTime(
      date.year,
      date.month,
      date.day,
      startTime.hour,
      startTime.minute,
    );
    final end = start.add(Duration(hours: durationHours));
    updateServiceTiming(startDateTime: start, endDateTime: end);
  }

  /// Updates Section 3: Pickup & Destination, calculating route distance if service available.
  Future<void> updateLocations({
    required String city,
    required String pickupAddress,
    required String destinationAddress,
    String venueName = '',
    String landmark = '',
  }) async {
    double? distance = state.draft.routeDistanceKm;
    if (routeDistanceService != null &&
        pickupAddress.trim().isNotEmpty &&
        destinationAddress.trim().isNotEmpty) {
      try {
        distance = await routeDistanceService!.estimateDistanceKm(
          pickupAddress: pickupAddress,
          destinationAddress: destinationAddress,
          city: city,
        );
      } catch (_) {}
    }

    state = state.copyWith(
      draft: state.draft.copyWith(
        city: city,
        pickupAddress: pickupAddress,
        destinationAddress: destinationAddress,
        venueName: venueName,
        landmark: landmark,
        routeDistanceKm: distance,
      ),
      clearError: true,
    );
  }

  /// Updates Section 4: Passenger Details
  void updatePassengerDetails({
    required String contactName,
    required String contactPhone,
    String? alternatePhone,
    required int passengerCount,
  }) {
    state = state.copyWith(
      draft: state.draft.copyWith(
        primaryContactName: contactName,
        primaryContactPhone: contactPhone,
        alternateContactPhone: alternatePhone,
        passengerCount: passengerCount,
      ),
      clearError: true,
    );
  }

  /// Navigates directly to a given step index.
  void goToStep(int step) {
    if (step >= 0 && step <= 3) {
      state = state.copyWith(activeStep: step, clearError: true);
    }
  }

  /// Navigates to next step if current step is valid.
  bool nextStep() {
    switch (state.activeStep) {
      case 0:
        if (!state.draft.isCeremonyValid) {
          state = state.copyWith(
            errorMessage: 'Please select an occasion and chauffeur attire.',
          );
          return false;
        }
        break;
      case 1:
        if (!state.draft.isDateTimeValid) {
          state = state.copyWith(
            errorMessage:
                'Please select a valid ceremony start & end time (minimum 1 hour duration).',
          );
          return false;
        }
        break;
      case 2:
        if (!state.draft.isLocationsValid) {
          state = state.copyWith(
            errorMessage:
                'Please specify pickup address and destination venue.',
          );
          return false;
        }
        break;
      case 3:
        if (!state.draft.isPassengerDetailsValid) {
          state = state.copyWith(
            errorMessage:
                'Please provide a valid primary contact name and 10-digit mobile number.',
          );
          return false;
        }
        break;
    }

    if (state.activeStep < 3) {
      state = state.copyWith(
        activeStep: state.activeStep + 1,
        clearError: true,
      );
      return true;
    }
    return true;
  }

  /// Navigates to previous step.
  void previousStep() {
    if (state.activeStep > 0) {
      state = state.copyWith(
        activeStep: state.activeStep - 1,
        clearError: true,
      );
    }
  }

  /// Finalizes the booking draft and persists it to [BookingRepository].
  Future<bool> submitDraft() async {
    if (!state.draft.isComplete) {
      state = state.copyWith(
        errorMessage: 'Please complete all required event and contact details.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    final result = await bookingRepository.createBookingDraft(state.draft);

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
      (saved) {
        state = state.copyWith(
          isLoading: false,
          savedDraft: saved,
          clearError: true,
        );
        return true;
      },
    );
  }
}

/// Provider family for booking draft controller keyed by vehicle details.
final bookingDraftControllerProvider =
    StateNotifierProvider.family<
      BookingDraftController,
      BookingDraftState,
      VehicleDetails
    >((ref, vehicle) {
      final bookingRepo = ref.watch(bookingRepositoryProvider);
      final pricingPolicy = ref.watch(bookingPricingPolicyProvider);
      final routeDistanceService = ref.watch(routeDistanceServiceProvider);
      return BookingDraftController(
        bookingRepository: bookingRepo,
        pricingPolicy: pricingPolicy,
        routeDistanceService: routeDistanceService,
        vehicle: vehicle,
      );
    });
