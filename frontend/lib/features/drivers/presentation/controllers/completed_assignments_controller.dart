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
