import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers/app_providers.dart';
import '../../../bookings/domain/entities/booking_status.dart';
import '../../../bookings/domain/repositories/booking_repository.dart';
import '../../domain/entities/driver_active_trip.dart';
import '../../domain/entities/driver_trip_stage.dart';
import 'driver_dashboard_controller.dart' show currentDriverIdProvider;

/// State for the Chauffeur Console "Completed Assignments" section.
@immutable
class CompletedAssignmentsState {
  final List<DriverActiveTrip> assignments;
  final bool isLoading;
  final String? errorMessage;

  const CompletedAssignmentsState({
    this.assignments = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  CompletedAssignmentsState copyWith({
    List<DriverActiveTrip>? assignments,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CompletedAssignmentsState(
      assignments: assignments ?? this.assignments,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Controller loading the chauffeur's completed ceremonial assignment history.
///
/// Only bookings that have actually reached the COMPLETED lifecycle state are
/// listed — nothing is shown as completed before the service has concluded.
class CompletedAssignmentsController
    extends StateNotifier<CompletedAssignmentsState> {
  final BookingRepository bookingRepository;
  final String driverId;

  CompletedAssignmentsController({
    required this.bookingRepository,
    required this.driverId,
  }) : super(const CompletedAssignmentsState(isLoading: true)) {
    loadCompleted();
  }

  Future<void> loadCompleted() async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await bookingRepository.getCompletedBookings(
      driverId: driverId,
    );

    if (!mounted) return; // provider may have been disposed mid-flight

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
      (bookings) => state = state.copyWith(
        isLoading: false,
        assignments: bookings
            // Defensive: filter to completed records only, newest first.
            .where((b) => b.status == BookingStatus.completed)
            .map(
              (b) => DriverActiveTrip.fromBookingResult(
                b,
                stage: DriverTripStage.completed,
              ),
            )
            .toList(),
      ),
    );
  }
}

/// Provider exposing completed assignments for the Chauffeur Console.
final completedAssignmentsControllerProvider =
    StateNotifierProvider.autoDispose<
      CompletedAssignmentsController,
      CompletedAssignmentsState
    >((ref) {
      final bookingRepo = ref.watch(bookingRepositoryProvider);
      final driverId = ref.watch(currentDriverIdProvider);

      return CompletedAssignmentsController(
        bookingRepository: bookingRepo,
        driverId: driverId,
      );
    });

/// Aggregate payout view over the chauffeur's completed assignments.
///
/// The chauffeur earns 70% of each booking's estimated total (the platform
/// commission mirrors the PRD's revenue-share note); advance tokens are
/// already collected and excluded from the payout figure.
@immutable
class DriverEarningsSummary {
  static const double chauffeurShare = 0.70;

  final int assignmentCount;
  final int grossPaise;
  final int hoursOnDuty;

  const DriverEarningsSummary({
    required this.assignmentCount,
    required this.grossPaise,
    required this.hoursOnDuty,
  });

  /// 70% chauffeur share of gross booking value, in paise.
  int get netPayoutPaise => (grossPaise * chauffeurShare).round();

  double get grossRupees => grossPaise / 100;
  double get netPayoutRupees => netPayoutPaise / 100;

  String get netPayoutFormatted {
    final rupees = netPayoutPaise / 100;
    return '₹${rupees.toStringAsFixed(rupees == rupees.roundToDouble() ? 0 : 2)}';
  }

  factory DriverEarningsSummary.fromAssignments(
    List<DriverActiveTrip> assignments,
  ) {
    var gross = 0;
    var hours = 0;
    for (final trip in assignments) {
      gross += trip.estimatedTotalPaise ?? 0;
      hours += trip.serviceEndDateTime
          .difference(trip.serviceStartDateTime)
          .inHours;
    }
    return DriverEarningsSummary(
      assignmentCount: assignments.length,
      grossPaise: gross,
      hoursOnDuty: hours,
    );
  }
}

/// Provider deriving the earnings summary from the completed assignments.
final driverEarningsSummaryProvider = Provider<DriverEarningsSummary>((ref) {
  final state = ref.watch(completedAssignmentsControllerProvider);
  return DriverEarningsSummary.fromAssignments(state.assignments);
});
