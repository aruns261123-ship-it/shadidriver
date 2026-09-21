import '../../../../core/result/result.dart';
import '../../../drivers/domain/entities/driver_decline_reason.dart';
import '../entities/booking_draft.dart';
import '../entities/booking_submission_request.dart';
import '../entities/booking_submission_result.dart';
import '../entities/booking_summary.dart';
import '../entities/customer_fleet_intent.dart';
import '../entities/fleet_availability_result.dart';
import '../entities/group_booking.dart';
import '../entities/group_booking_submission_request.dart';

/// Pure Dart domain contract for booking lifecycle and draft operations.
abstract interface class BookingRepository {
  /// Persists a new customer booking draft (Milestone 4A).
  Future<Result<BookingDraft>> createBookingDraft(BookingDraft draft);

  /// Retrieves an existing booking draft by ID.
  Future<Result<BookingDraft?>> getBookingDraft(String draftId);

  /// Updates or saves changes to an in-progress draft.
  Future<Result<void>> saveBookingDraft(BookingDraft draft);

  /// Submits customer booking intent with idempotency protection (Milestone 4B).
  ///
  /// Returns server-authoritative [BookingSubmissionResult] in `requested` status.
  Future<Result<BookingSubmissionResult>> submitBooking(
    BookingSubmissionRequest request,
  );

  /// Retrieves a previous submission result by booking ID.
  Future<Result<BookingSubmissionResult?>> getSubmissionResult(
    String bookingId,
  );

  /// Fetches an authoritative booking record by ID.
  Future<Result<BookingSummary>> getBookingById(String bookingId);

  /// Fetches customer's active and historical bookings.
  Future<Result<List<BookingSummary>>> getMyBookings({
    int page = 1,
    int limit = 20,
    String? statusFilter,
  });

  /// Transitions a booking lifecycle state in accordance with BOOKING_STATE_MACHINE.md.
  Future<Result<BookingSummary>> transitionState({
    required String bookingId,
    required String action,
    required int currentVersion,
    Map<String, dynamic>? metadata,
  });

  /// Cancels an active or pending booking subject to cancellation policies.
  Future<Result<void>> cancelBooking({
    required String bookingId,
    required String reason,
  });

  /// Retrieves pending booking requests in REQUESTED status eligible for [driverId].
  Future<Result<List<BookingSubmissionResult>>> getDriverBookingRequests({
    required String driverId,
  });

  /// Retrieves booking request details for a chauffeur review.
  Future<Result<BookingSubmissionResult>> getDriverBookingDetails({
    required String bookingId,
    required String driverId,
  });

  /// Driver accepts a ceremonial booking offer. Enforces concurrency protection.
  ///
  /// Fails with [ConflictFailure] if the booking has already been accepted by another chauffeur.
  Future<Result<BookingSubmissionResult>> acceptBooking({
    required String bookingId,
    required String driverId,
  });

  /// Driver declines a ceremonial booking offer with a mandatory reason.
  Future<Result<void>> declineBooking({
    required String bookingId,
    required String driverId,
    required DriverDeclineReason reason,
    String? notes,
  });

  /// Checks fleet availability for a multi-vehicle / group booking intent.
  Future<Result<FleetAvailabilityResult>> checkFleetAvailability(
    CustomerFleetIntent intent,
  );

  /// Submits a multi-vehicle / group booking with parent booking and individual vehicle assignments.
  Future<Result<GroupBooking>> submitGroupBooking(
    GroupBookingSubmissionRequest request,
  );

  /// Retrieves a group booking and its vehicle assignments by ID.
  Future<Result<GroupBooking?>> getGroupBooking(String parentBookingId);
}
