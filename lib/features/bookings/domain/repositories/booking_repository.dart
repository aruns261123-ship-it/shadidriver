import '../../../../core/result/result.dart';
import '../entities/booking_draft.dart';
import '../entities/booking_summary.dart';

/// Pure Dart domain contract for booking lifecycle and draft operations.
abstract interface class BookingRepository {
  /// Persists a new customer booking draft (Milestone 4A).
  Future<Result<BookingDraft>> createBookingDraft(BookingDraft draft);

  /// Retrieves an existing booking draft by ID.
  Future<Result<BookingDraft?>> getBookingDraft(String draftId);

  /// Updates or saves changes to an in-progress draft.
  Future<Result<void>> saveBookingDraft(BookingDraft draft);

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
}
