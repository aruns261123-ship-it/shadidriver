import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers/app_providers.dart';
import '../../../vehicles/domain/entities/vehicle_details.dart';
import '../../domain/entities/booking_draft.dart';
import '../../domain/entities/search_handoff.dart';
import '../../domain/policies/booking_pricing_policy.dart';
import '../../domain/repositories/booking_repository.dart';
import '../../domain/services/route_distance_service.dart';

/// State object representing the active draft creation or edit flow.
class BookingDraftState {
  final BookingDraft draft;
  final BookingDraft? originalDraft;
  final int activeStep;
  final bool isLoading;
  final bool isLoadingDraft;
  final String? errorMessage;
  final BookingDraft? savedDraft;
  final bool isEditMode;
  final bool isUpdateSuccess;

  const BookingDraftState({
    required this.draft,
    this.originalDraft,
    this.activeStep = 0,
    this.isLoading = false,
    this.isLoadingDraft = false,
    this.errorMessage,
    this.savedDraft,
    this.isEditMode = false,
    this.isUpdateSuccess = false,
  });

  bool get isSaved => savedDraft != null;
  bool get hasUnsavedChanges =>
      isEditMode && originalDraft != null && draft != originalDraft;

  BookingDraftState copyWith({
    BookingDraft? draft,
    BookingDraft? originalDraft,
    int? activeStep,
    bool? isLoading,
    bool? isLoadingDraft,
    String? errorMessage,
    BookingDraft? savedDraft,
    bool? isEditMode,
    bool? isUpdateSuccess,
    bool clearError = false,
    bool clearSavedDraft = false,
  }) {
    return BookingDraftState(
      draft: draft ?? this.draft,
      originalDraft: originalDraft ?? this.originalDraft,
      activeStep: activeStep ?? this.activeStep,
      isLoading: isLoading ?? this.isLoading,
      isLoadingDraft: isLoadingDraft ?? this.isLoadingDraft,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      savedDraft: clearSavedDraft ? null : (savedDraft ?? this.savedDraft),
      isEditMode: isEditMode ?? this.isEditMode,
      isUpdateSuccess: isUpdateSuccess ?? this.isUpdateSuccess,
    );
  }
}

/// Controller managing customer booking draft updates, step transitions, and persistence.
class BookingDraftController extends StateNotifier<BookingDraftState> {
  final BookingRepository bookingRepository;
  final BookingPricingPolicy pricingPolicy;
  final RouteDistanceService? routeDistanceService;

  final SearchHandoff? searchHandoff;

  BookingDraftController({
    required this.bookingRepository,
    required this.pricingPolicy,
    this.routeDistanceService,
    required VehicleDetails vehicle,
    String? initialDraftId,
    this.searchHandoff,
  }) : super(
         _createInitialState(
           vehicle: vehicle,
           pricingPolicy: pricingPolicy,
           initialDraftId: initialDraftId,
         ),
       ) {
    if (initialDraftId != null && initialDraftId.isNotEmpty) {
      loadExistingDraft(initialDraftId);
    } else if (searchHandoff != null && searchHandoff!.hasAny) {
      _applySearchHandoff();
    }
  }

  /// Seeds the fresh draft with the customer's search intent (destination,
  /// event date, occasion, passenger count) so nothing is re-entered.
  void _applySearchHandoff() {
    final handoff = searchHandoff!;
    var draft = state.draft;

    final destination = handoff.destination?.trim() ?? '';
    final pickup = handoff.pickupLocation?.trim() ?? '';
    if (destination.isNotEmpty || pickup.isNotEmpty) {
      draft = draft.copyWith(
        destinationAddress: destination.isNotEmpty ? destination : draft.destinationAddress,
        pickupAddress: pickup.isNotEmpty ? pickup : draft.pickupAddress,
      );
    }
    if (handoff.occasion != null && handoff.occasion!.trim().isNotEmpty) {
      draft = draft.copyWith(ceremonyType: handoff.occasion!.trim());
    }
    if (handoff.eventDate != null) {
      // Keep the draft's default 4:00 PM slot; move it to the searched date.
      final start = draft.serviceStartDateTime;
      final newStart = DateTime(
        handoff.eventDate!.year,
        handoff.eventDate!.month,
        handoff.eventDate!.day,
        start.hour,
        start.minute,
      );
      draft = draft.copyWith(
        serviceStartDateTime: newStart,
        serviceEndDateTime: newStart.add(Duration(hours: draft.durationHours)),
      );
    }
    if (handoff.passengerCount != null && handoff.passengerCount! > 0) {
      draft = draft.copyWith(passengerCount: handoff.passengerCount!);
    }

    state = state.copyWith(draft: draft, clearError: true);
  }

  static BookingDraftState _createInitialState({
    required VehicleDetails vehicle,
    required BookingPricingPolicy pricingPolicy,
    String? initialDraftId,
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
        // No chauffeur is bound to a customer selection: ShadiDriver operations
        // assigns one internally after the request is reviewed.
        chauffeurId: '',
        basePricePaise: pricing.basePricePaise,
        estimatedTotalPaise: pricing.estimatedTotalPaise,
        advanceTokenPaise: pricing.advanceTokenPaise,
        advanceTokenLabel: pricing.advanceTokenLabel,
        durationHours: defaultDuration,
      ),
      isLoadingDraft: initialDraftId != null && initialDraftId.isNotEmpty,
      isEditMode: initialDraftId != null && initialDraftId.isNotEmpty,
    );
  }

  /// Loads an existing draft from repository and populates state for editing.
  Future<bool> loadExistingDraft(String draftId) async {
    state = state.copyWith(isLoadingDraft: true, clearError: true);
    final result = await bookingRepository.getBookingDraft(draftId);

    return result.fold(
      (failure) {
        state = state.copyWith(
          isLoadingDraft: false,
          errorMessage: 'Unable to load existing draft: ${failure.message}',
        );
        return false;
      },
      (existing) {
        if (existing == null) {
          state = state.copyWith(
            isLoadingDraft: false,
            errorMessage: 'Draft not found with ID: $draftId',
          );
          return false;
        }

        state = state.copyWith(
          draft: existing,
          originalDraft: existing,
          isEditMode: true,
          clearSavedDraft: true,
          isLoadingDraft: false,
          clearError: true,
        );
        return true;
      },
    );
  }

  /// Discards unsaved edits and restores the original draft values.
  void resetUnsavedChanges() {
    if (state.originalDraft != null) {
      state = state.copyWith(draft: state.originalDraft, clearError: true);
    }
  }

  /// Updates vehicle selection, recalculates pricing, and updates state.
  void updateVehicle(VehicleDetails newVehicle) {
    final diffHours = state.draft.serviceEndDateTime
        .difference(state.draft.serviceStartDateTime)
        .inHours;
    final durationHours = diffHours > 0 ? diffHours : 1;

    final pricing = pricingPolicy.calculatePricing(
      basePricePaise: newVehicle.pricing.basePriceCents,
      durationHours: durationHours,
    );

    state = state.copyWith(
      draft: state.draft.copyWith(
        vehicleId: newVehicle.id,
        vehicleName: '${newVehicle.make} ${newVehicle.model}',
        vehicleClass: newVehicle.vehicleClass,
        chauffeurId: '',
        basePricePaise: pricing.basePricePaise,
        estimatedTotalPaise: pricing.estimatedTotalPaise,
        advanceTokenPaise: pricing.advanceTokenPaise,
        advanceTokenLabel: pricing.advanceTokenLabel,
      ),
      clearError: true,
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
    final pickupChanged =
        pickupAddress.trim() != state.draft.pickupAddress.trim();
    final destChanged =
        destinationAddress.trim() != state.draft.destinationAddress.trim();
    final cityChanged = city.trim() != state.draft.city.trim();

    if (routeDistanceService != null &&
        pickupAddress.trim().isNotEmpty &&
        destinationAddress.trim().isNotEmpty &&
        (pickupChanged || destChanged || cityChanged || distance == null)) {
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
          // The server requires 5..500 characters for both addresses
          // (`@Length(5, 500)`); say exactly which field is wrong instead of a
          // generic prompt that leads to a rejected submission.
          state = state.copyWith(
            errorMessage:
                state.draft.locationValidationMessage ??
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
  /// In edit mode, updates the existing draft in repository and retains the exact same draft ID.
  /// In create mode, creates a new draft and transitions to draft saved summary.
  Future<bool> submitDraft() async {
    if (state.isLoading) return false;

    if (!state.draft.isComplete) {
      state = state.copyWith(
        errorMessage:
            state.draft.locationValidationMessage ??
            'Please complete all required event and contact details.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    if (state.isEditMode) {
      final updated = state.draft.copyWith(status: BookingDraftStatus.saved);
      final result = await bookingRepository.saveBookingDraft(updated);

      return result.fold(
        (failure) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: failure.message,
          );
          return false;
        },
        (_) {
          state = state.copyWith(
            draft: updated,
            originalDraft: updated,
            isLoading: false,
            isUpdateSuccess: true,
            clearError: true,
          );
          return true;
        },
      );
    } else {
      final result = await bookingRepository.createBookingDraft(state.draft);

      return result.fold(
        (failure) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: failure.message,
          );
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
}

/// Parameters for family-scoped booking draft controller.
@immutable
class BookingDraftParams {
  final VehicleDetails vehicle;
  final String? draftId;

  /// Search intent carried forward so the customer never re-enters it
  /// (destination, event date, occasion, passenger count).
  final SearchHandoff? searchHandoff;

  const BookingDraftParams({
    required this.vehicle,
    this.draftId,
    this.searchHandoff,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookingDraftParams &&
          other.vehicle.id == vehicle.id &&
          other.draftId == draftId &&
          other.searchHandoff == searchHandoff);

  @override
  int get hashCode => Object.hash(vehicle.id, draftId, searchHandoff);
}

/// Provider family for booking draft controller keyed by vehicle and optional draft ID.
final bookingDraftControllerProvider = StateNotifierProvider.autoDispose
    .family<BookingDraftController, BookingDraftState, BookingDraftParams>((
      ref,
      params,
    ) {
      final bookingRepo = ref.watch(bookingRepositoryProvider);
      final pricingPolicy = ref.watch(bookingPricingPolicyProvider);
      final routeDistanceService = ref.watch(routeDistanceServiceProvider);
      return BookingDraftController(
        bookingRepository: bookingRepo,
        pricingPolicy: pricingPolicy,
        routeDistanceService: routeDistanceService,
        vehicle: params.vehicle,
        initialDraftId: params.draftId,
        searchHandoff: params.searchHandoff,
      );
    });
