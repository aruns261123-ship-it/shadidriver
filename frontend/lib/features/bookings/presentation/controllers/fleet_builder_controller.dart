import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers/app_providers.dart';
import '../../domain/entities/customer_fleet_intent.dart';
import '../../domain/entities/fleet_availability_result.dart';
import '../../domain/entities/group_booking.dart';
import '../../domain/entities/group_booking_submission_request.dart';
import '../../domain/repositories/booking_repository.dart';
import 'fleet_builder_state.dart';

/// Composition request for a group booking.
class GroupBookingIntent {
  final String ceremonyType;
  final String city;
  final String pickupAddress;
  final String destinationAddress;
  final String primaryContactName;
  final String primaryContactPhone;
  final DateTime serviceStartDateTime;
  final DateTime serviceEndDateTime;
  final int passengerCount;

  const GroupBookingIntent({
    required this.ceremonyType,
    required this.city,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.primaryContactName,
    required this.primaryContactPhone,
    required this.serviceStartDateTime,
    required this.serviceEndDateTime,
    required this.passengerCount,
  });
}

/// Stages of the group-booking wizard: build → availability → confirm → done.
enum GroupBookingStage { build, availability, confirmation, submitted }

class GroupBookingState {
  final List<FleetLineState> lines;

  /// Latest availability check result (null = not yet checked).
  final FleetAvailabilityResult? availability;

  /// Customer's explicit approval for a shortfall composition. Required
  /// whenever availability is partial — the engine NEVER substitutes silently.
  final bool shortfallApproved;

  final GroupBookingStage stage;
  final bool isChecking;
  final bool isSubmitting;
  final String? errorMessage;
  final GroupBooking? submittedGroup;

  const GroupBookingState({
    required this.lines,
    this.availability,
    this.shortfallApproved = false,
    this.stage = GroupBookingStage.build,
    this.isChecking = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.submittedGroup,
  });

  int get totalVehicles =>
      lines.fold(0, (sum, l) => sum + l.quantity);

  int get totalCapacity =>
      lines.fold(0, (sum, l) => sum + l.quantity * l.seatingCapacity);

  bool get hasShortfall =>
      availability != null && !availability!.isFullyAvailable;

  /// Submission gate: a partial-availability fleet REQUIRES the explicit
  /// customer confirmation before any group booking can be created.
  bool get canSubmit =>
      lines.isNotEmpty &&
      totalVehicles > 0 &&
      availability != null &&
      (!hasShortfall || shortfallApproved);

  GroupBookingState copyWith({
    List<FleetLineState>? lines,
    FleetAvailabilityResult? availability,
    bool clearAvailability = false,
    bool? shortfallApproved,
    GroupBookingStage? stage,
    bool? isChecking,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    GroupBooking? submittedGroup,
  }) {
    return GroupBookingState(
      lines: lines ?? this.lines,
      availability:
          clearAvailability ? null : (availability ?? this.availability),
      shortfallApproved: shortfallApproved ?? this.shortfallApproved,
      stage: stage ?? this.stage,
      isChecking: isChecking ?? this.isChecking,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      submittedGroup: submittedGroup ?? this.submittedGroup,
    );
  }
}

class GroupBookingController extends StateNotifier<GroupBookingState> {
  final Ref _ref;

  GroupBookingController(this._ref, {List<FleetLineState> initialLines = const []})
      : super(GroupBookingState(lines: initialLines));

  BookingRepository get _repo => _ref.read(bookingRepositoryProvider);

  void setQuantity(String vehicleTypeId, int quantity) {
    final updated = state.lines
        .map((l) =>
            l.vehicleTypeId == vehicleTypeId ? l.copyWith(quantity: quantity) : l)
        .toList();
    // Any composition change invalidates the previous availability check and
    // the shortfall approval — the customer must re-confirm.
    state = state.copyWith(
      lines: updated,
      clearAvailability: true,
      shortfallApproved: false,
      stage: GroupBookingStage.build,
      clearError: true,
    );
  }

  void removeLine(String vehicleTypeId) {
    state = state.copyWith(
      lines: state.lines
          .where((l) => l.vehicleTypeId != vehicleTypeId)
          .toList(),
      clearAvailability: true,
      shortfallApproved: false,
      stage: GroupBookingStage.build,
      clearError: true,
    );
  }

  void addLine(FleetLineState line) {
    if (state.lines.any((l) => l.vehicleTypeId == line.vehicleTypeId)) return;
    state = state.copyWith(
      lines: [...state.lines, line],
      clearAvailability: true,
      shortfallApproved: false,
      stage: GroupBookingStage.build,
      clearError: true,
    );
  }

  void approveShortfall() {
    state = state.copyWith(shortfallApproved: true);
  }

  void rejectShortfall() {
    state = state.copyWith(
      shortfallApproved: false,
      stage: GroupBookingStage.build,
      clearAvailability: true,
    );
  }

  /// Checks REAL availability through the backend for the current composition.
  Future<bool> checkAvailability(GroupBookingIntent intent) async {
    if (state.lines.isEmpty) {
      state = state.copyWith(errorMessage: 'Add at least one vehicle to the fleet.');
      return false;
    }
    state = state.copyWith(isChecking: true, clearError: true);
    final units = <String, int>{
      for (final l in state.lines) l.vehicleTypeId: l.quantity,
    };
    final result = await _repo.checkFleetAvailability(
      CustomerFleetIntent.mixed(
        passengerCount: intent.passengerCount,
        units: units,
      ),
      serviceStartTime: intent.serviceStartDateTime,
      serviceEndTime: intent.serviceEndDateTime,
      city: intent.city,
    );
    return result.fold(
      (failure) {
        state = state.copyWith(
          isChecking: false,
          errorMessage: failure.message,
        );
        return false;
      },
      (availability) {
        state = state.copyWith(
          isChecking: false,
          availability: availability,
          shortfallApproved: false,
          stage: GroupBookingStage.availability,
        );
        return true;
      },
    );
  }

  /// Submits the group booking (transactional, idempotent on the backend).
  Future<bool> submit(GroupBookingIntent intent) async {
    if (!state.canSubmit) {
      state = state.copyWith(
        errorMessage: state.hasShortfall && !state.shortfallApproved
            ? 'Explicit confirmation is required for the shortfall composition.'
            : 'Check fleet availability before submitting.',
      );
      return false;
    }
    state = state.copyWith(isSubmitting: true, clearError: true);
    final units = <String, int>{
      for (final l in state.lines) l.vehicleTypeId: l.quantity,
    };
    final request = GroupBookingSubmissionRequest(
      fleetIntent: CustomerFleetIntent.mixed(
        passengerCount: intent.passengerCount,
        units: units,
      ),
      ceremonyType: intent.ceremonyType,
      serviceStartDateTime: intent.serviceStartDateTime,
      serviceEndDateTime: intent.serviceEndDateTime,
      city: intent.city,
      pickupAddress: intent.pickupAddress,
      destinationAddress: intent.destinationAddress,
      primaryContactName: intent.primaryContactName,
      primaryContactPhone: intent.primaryContactPhone,
      idempotencyKey:
          'grp-${intent.serviceStartDateTime.millisecondsSinceEpoch ~/ 60000}'
          '-${units.toString().hashCode.abs().toRadixString(36)}',
    );
    final result = await _repo.submitGroupBooking(request);
    return result.fold(
      (failure) {
        state = state.copyWith(isSubmitting: false, errorMessage: failure.message);
        return false;
      },
      (group) {
        state = state.copyWith(
          isSubmitting: false,
          submittedGroup: group,
          stage: GroupBookingStage.submitted,
        );
        return true;
      },
    );
  }
}

/// Family parameterized by the requested fleet composition seed.
final groupBookingControllerProvider = StateNotifierProvider.autoDispose
    .family<GroupBookingController, GroupBookingState, List<FleetLineState>>(
  (ref, initialLines) => GroupBookingController(ref, initialLines: initialLines),
);
