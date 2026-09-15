import '../../../../core/errors/failures.dart';
import '../../../../core/result/result.dart';
import '../domain/entities/booking_draft.dart';
import '../domain/entities/booking_status.dart';
import '../domain/entities/booking_submission_request.dart';
import '../domain/entities/booking_submission_result.dart';
import '../domain/entities/booking_summary.dart';
import '../domain/repositories/booking_repository.dart';

/// In-memory mock implementation of [BookingRepository] for Milestones 4A & 4B.
///
/// Simulates server-authoritative submission intent and idempotent key handling.
class MockBookingRepository implements BookingRepository {
  final Map<String, BookingDraft> _drafts = {};
  final Map<String, BookingSummary> _bookings = {};
  final Map<String, BookingSubmissionResult> _idempotentSubmissions = {};
  final Map<String, BookingSubmissionResult> _submissionResults = {};
  int _referenceCounter = 101;

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
    await Future.delayed(const Duration(milliseconds: 150));
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
  Future<Result<BookingSubmissionResult>> submitBooking(
    BookingSubmissionRequest request,
  ) async {
    // Artificial latency to simulate server communication
    await Future.delayed(const Duration(milliseconds: 250));

    // 1. Idempotency Check: if identical key was submitted, return cached result with replay flag
    if (_idempotentSubmissions.containsKey(request.idempotencyKey)) {
      final existing = _idempotentSubmissions[request.idempotencyKey]!;
      final replayResult = BookingSubmissionResult(
        bookingId: existing.bookingId,
        bookingReference: existing.bookingReference,
        status: existing.status,
        submittedAt: existing.submittedAt,
        vehicleId: existing.vehicleId,
        vehicleName: existing.vehicleName,
        vehicleClass: existing.vehicleClass,
        chauffeurId: existing.chauffeurId,
        ceremonyType: existing.ceremonyType,
        ceremonialAttire: existing.ceremonialAttire,
        eventDate: existing.eventDate,
        durationHours: existing.durationHours,
        pickupAddress: existing.pickupAddress,
        destinationAddress: existing.destinationAddress,
        primaryContactName: existing.primaryContactName,
        primaryContactPhone: existing.primaryContactPhone,
        estimatedTotalPaise: existing.estimatedTotalPaise,
        advanceTokenPaise: existing.advanceTokenPaise,
        advanceTokenLabel: existing.advanceTokenLabel,
        nextStepMessage: existing.nextStepMessage,
        isIdempotentReplay: true,
      );
      return Result.success(replayResult);
    }

    // 2. Validate request
    if (!request.isValid) {
      return Result.failure(
        const ValidationFailure(
          'Incomplete ceremonial booking request. Please check required fields.',
        ),
      );
    }

    // 3. Create server-authoritative booking result in REQUESTED state
    final bookingId =
        'bk_${request.vehicleId}_${DateTime.now().millisecondsSinceEpoch}';
    final refCode = 'SD-2026-${_referenceCounter.toString().padLeft(4, '0')}';
    _referenceCounter++;

    final submissionResult = BookingSubmissionResult(
      bookingId: bookingId,
      bookingReference: refCode,
      status: BookingStatus.requested,
      submittedAt: DateTime.now(),
      vehicleId: request.vehicleId,
      vehicleName: request.vehicleName,
      vehicleClass: request.vehicleClass,
      chauffeurId: request.chauffeurId,
      ceremonyType: request.ceremonyType,
      ceremonialAttire: request.ceremonialAttire,
      eventDate: request.eventDate,
      durationHours: request.durationHours,
      pickupAddress: request.pickupAddress,
      destinationAddress: request.destinationAddress,
      primaryContactName: request.primaryContactName,
      primaryContactPhone: request.primaryContactPhone,
      estimatedTotalPaise: request.estimatedTotalPaise,
      advanceTokenPaise: request.advanceTokenPaise,
      advanceTokenLabel: request.advanceTokenLabel,
      nextStepMessage:
          'Your ceremonial reservation request has been received. Our operations team is confirming chauffeur allocation. You will receive notification once confirmed.',
      isIdempotentReplay: false,
    );

    // 4. Cache idempotency record and result
    _idempotentSubmissions[request.idempotencyKey] = submissionResult;
    _submissionResults[bookingId] = submissionResult;

    // 5. Store booking summary for customer bookings list
    final summary = BookingSummary(
      id: bookingId,
      reference: refCode,
      serviceCategory: request.ceremonyType,
      status: 'REQUESTED',
      eventStartTime: DateTime(
        request.eventDate.year,
        request.eventDate.month,
        request.eventDate.day,
        request.startTimeHour,
        request.startTimeMinute,
      ),
      eventEndTime: DateTime(
        request.eventDate.year,
        request.eventDate.month,
        request.eventDate.day,
        request.startTimeHour + request.durationHours,
        request.startTimeMinute,
      ),
      pickupAddress: request.pickupAddress,
      totalAmountCents: request.estimatedTotalPaise,
      advanceTokenCents: request.advanceTokenPaise,
      version: 1,
    );
    _bookings[bookingId] = summary;

    return Result.success(submissionResult);
  }

  @override
  Future<Result<BookingSubmissionResult?>> getSubmissionResult(
    String bookingId,
  ) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return Result.success(_submissionResults[bookingId]);
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
