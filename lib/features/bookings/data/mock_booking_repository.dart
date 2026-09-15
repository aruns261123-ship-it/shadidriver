import '../../../../core/errors/failures.dart';
import '../../../../core/result/result.dart';
import '../domain/entities/booking_draft.dart';
import '../domain/entities/booking_summary.dart';
import '../domain/repositories/booking_repository.dart';

/// In-memory mock implementation of [BookingRepository] for Milestone 4A.
class MockBookingRepository implements BookingRepository {
  final Map<String, BookingDraft> _drafts = {};
  final Map<String, BookingSummary> _bookings = {};

  MockBookingRepository() {
    _seedMockBookings();
  }

  void _seedMockBookings() {
    final b1 = BookingSummary(
      id: 'b_mock_1',
      reference: 'SHD-2026-DLH-0192',
      serviceCategory: 'SVC_BARAAT',
      status: 'CONFIRMED',
      eventStartTime: DateTime(2026, 11, 20, 16, 0),
      eventEndTime: DateTime(2026, 11, 20, 22, 0),
      pickupAddress: 'The Oberoi, Dr Zakir Hussain Marg, New Delhi',
      totalAmountCents: 3500000,
      advanceTokenCents: 700000,
      version: 2,
    );
    _bookings[b1.id] = b1;
  }

  @override
  Future<Result<BookingDraft>> createBookingDraft(BookingDraft draft) async {
    // Artificial small delay to simulate network call
    await Future.delayed(const Duration(milliseconds: 200));

    final saved = draft.copyWith(status: BookingDraftStatus.saved);
    _drafts[saved.id] = saved;
    return Result.success(saved);
  }

  @override
  Future<Result<BookingDraft?>> getBookingDraft(String draftId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final draft = _drafts[draftId];
    return Result.success(draft);
  }

  @override
  Future<Result<void>> saveBookingDraft(BookingDraft draft) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _drafts[draft.id] = draft;
    return const Result.success(null);
  }

  @override
  Future<Result<BookingSummary>> getBookingById(String bookingId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final booking = _bookings[bookingId];
    if (booking != null) {
      return Result.success(booking);
    }
    return Result.failure(
      NotFoundFailure('Booking not found with ID: $bookingId'),
    );
  }

  @override
  Future<Result<List<BookingSummary>>> getMyBookings({
    int page = 1,
    int limit = 20,
    String? statusFilter,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    var list = _bookings.values.toList();
    if (statusFilter != null && statusFilter.isNotEmpty) {
      list = list.where((b) => b.status == statusFilter).toList();
    }
    return Result.success(list);
  }

  @override
  Future<Result<BookingSummary>> transitionState({
    required String bookingId,
    required String action,
    required int currentVersion,
    Map<String, dynamic>? metadata,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final booking = _bookings[bookingId];
    if (booking == null) {
      return Result.failure(
        NotFoundFailure('Booking not found with ID: $bookingId'),
      );
    }

    if (booking.version != currentVersion) {
      return Result.failure(
        const ConflictFailure(
          'Booking state has been modified by another party. Please refresh.',
        ),
      );
    }

    final updated = BookingSummary(
      id: booking.id,
      reference: booking.reference,
      serviceCategory: booking.serviceCategory,
      status: action == 'CANCEL' ? 'CANCELLED' : 'UPDATED',
      eventStartTime: booking.eventStartTime,
      eventEndTime: booking.eventEndTime,
      pickupAddress: booking.pickupAddress,
      totalAmountCents: booking.totalAmountCents,
      advanceTokenCents: booking.advanceTokenCents,
      version: currentVersion + 1,
    );
    _bookings[bookingId] = updated;
    return Result.success(updated);
  }

  @override
  Future<Result<void>> cancelBooking({
    required String bookingId,
    required String reason,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final booking = _bookings[bookingId];
    if (booking == null) {
      return Result.failure(
        NotFoundFailure('Booking not found with ID: $bookingId'),
      );
    }
    final updated = BookingSummary(
      id: booking.id,
      reference: booking.reference,
      serviceCategory: booking.serviceCategory,
      status: 'CANCELLED',
      eventStartTime: booking.eventStartTime,
      eventEndTime: booking.eventEndTime,
      pickupAddress: booking.pickupAddress,
      totalAmountCents: booking.totalAmountCents,
      advanceTokenCents: booking.advanceTokenCents,
      version: booking.version + 1,
    );
    _bookings[bookingId] = updated;
    return const Result.success(null);
  }
}
