import '../../../../core/errors/failures.dart';
import '../../../../core/result/result.dart';
import '../../drivers/domain/entities/driver_decline_reason.dart';
import '../domain/entities/booking_draft.dart';
import '../domain/entities/booking_status.dart';
import '../domain/entities/booking_submission_request.dart';
import '../domain/entities/booking_submission_result.dart';
import '../domain/entities/booking_summary.dart';
import '../domain/entities/customer_fleet_intent.dart';
import '../domain/entities/fleet_availability_result.dart';
import '../domain/entities/group_booking.dart';
import '../domain/entities/group_booking_submission_request.dart';
import '../domain/entities/vehicle_assignment.dart';
import '../domain/repositories/booking_repository.dart';

/// In-memory mock implementation of [BookingRepository] for Milestones 4A, 4B & 5.
///
/// Simulates server-authoritative submission intent, idempotent key handling,
/// and deterministic chauffeur concurrency locking.
class MockBookingRepository implements BookingRepository {
  final Map<String, BookingDraft> _drafts = {};
  final Map<String, BookingSummary> _bookings = {};
  final Map<String, BookingSubmissionResult> _idempotentSubmissions = {};
  final Map<String, BookingSubmissionResult> _submissionResults = {};
  final Map<String, Set<String>> _driverDeclines = {};

  /// Bookings transitioned to COMPLETED via [completeTrip]; survives even if
  /// the status snapshot is not updated, so history is never lost.
  final Set<String> _completedBookings = {};
  final Map<String, GroupBooking> _groupBookings = {};
  final Map<String, GroupBooking> _idempotentGroupSubmissions = {};
  int _referenceCounter = 101;
  int _groupCounter = 1;

  /// Optional lifecycle event sink (wired to the notification center in the
  /// app composition; nullable so domain tests stay dependency-free).
  void Function({required String title, required String body})? onLifecycleEvent;

  static const Map<String, int> _mockInventory = {
    'Toyota Innova Crysta': 5,
    'Toyota Camry': 4,
    'BMW 5 Series': 3,
    'Mercedes-Benz E-Class': 2,
  };

  static const Map<String, int> _modelCapacity = {
    'Toyota Innova Crysta': 6,
    'Toyota Camry': 4,
    'BMW 5 Series': 4,
    'Mercedes-Benz E-Class': 4,
  };

  static const Map<String, int> _modelPricePaise = {
    'Toyota Innova Crysta': 2500000,
    'Toyota Camry': 3000000,
    'BMW 5 Series': 4500000,
    'Mercedes-Benz E-Class': 5500000,
  };

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

    // Seeded booking in REQUESTED state for Driver Console testing
    final req1 = BookingSubmissionResult(
      bookingId: 'bk_mock_req_1',
      bookingReference: 'SD-2026-0100',
      status: BookingStatus.requested,
      submittedAt: DateTime(2026, 9, 15, 10, 30),
      vehicleId: 'v1',
      vehicleName: 'BMW 5 Series',
      vehicleClass: 'Luxury Sedan',
      chauffeurId: 'd1',
      ceremonyType: 'Baraat',
      ceremonialAttire: 'Royal Bandhgala & Gold Safa',
      serviceStartDateTime: DateTime(2026, 11, 20, 16, 0),
      serviceEndDateTime: DateTime(2026, 11, 20, 24, 0),
      routeDistanceKm: 24.5,
      pickupAddress: 'The Oberoi Hotel, New Delhi',
      destinationAddress: 'Grand Imperial Banquets, MG Road',
      primaryContactName: 'Vikram Malhotra',
      primaryContactPhone: '9810012345',
      estimatedTotalPaise: 2500000,
      advanceTokenPaise: 500000,
      advanceTokenLabel: 'Advance Token (20%)',
      nextStepMessage:
          'Your ceremonial reservation request has been received. Our operations team is confirming chauffeur allocation.',
    );
    _submissionResults[req1.bookingId] = req1;

    final summaryReq1 = BookingSummary(
      id: req1.bookingId,
      reference: req1.bookingReference,
      serviceCategory: req1.ceremonyType,
      status: 'REQUESTED',
      eventStartTime: DateTime(2026, 11, 20, 16, 0),
      eventEndTime: DateTime(2026, 11, 20, 24, 0),
      pickupAddress: req1.pickupAddress,
      destinationAddress: req1.destinationAddress,
      routeDistanceKm: req1.routeDistanceKm,
      vehicleName: req1.vehicleName,
      chauffeurName: 'Rajesh Kumar',
      totalAmountCents: req1.estimatedTotalPaise,
      advanceTokenCents: req1.advanceTokenPaise,
      version: 1,
    );
    _bookings[req1.bookingId] = summaryReq1;
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
        serviceStartDateTime: existing.serviceStartDateTime,
        serviceEndDateTime: existing.serviceEndDateTime,
        routeDistanceKm: existing.routeDistanceKm,
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
      serviceStartDateTime: request.serviceStartDateTime,
      serviceEndDateTime: request.serviceEndDateTime,
      routeDistanceKm: request.routeDistanceKm,
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
      eventStartTime: request.serviceStartDateTime,
      eventEndTime: request.serviceEndDateTime,
      pickupAddress: request.pickupAddress,
      destinationAddress: request.destinationAddress,
      routeDistanceKm: request.routeDistanceKm,
      vehicleName: request.vehicleName,
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

  @override
  Future<Result<List<BookingSubmissionResult>>> getDriverBookingRequests({
    required String driverId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final declined = _driverDeclines[driverId] ?? <String>{};
    final requests = _submissionResults.values
        .where(
          (r) =>
              r.status == BookingStatus.requested &&
              !declined.contains(r.bookingId),
        )
        .toList();
    return Result.success(requests);
  }

  @override
  Future<Result<List<BookingSubmissionResult>>> getCompletedBookings({
    required String driverId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final completed = _submissionResults.values
        .where(
          (r) =>
              r.chauffeurId == driverId &&
              (r.status == BookingStatus.completed ||
                  _completedBookings.contains(r.bookingId)),
        )
        .toList()
      ..sort((a, b) => b.serviceEndDateTime.compareTo(a.serviceEndDateTime));
    return Result.success(completed);
  }

  /// Lifecycle subsets used by the active-assignment and dispatch-monitor
  /// queries below. Terminal/back-office states never render as live work.
  static const _nonActiveStatuses = {
    BookingStatus.requested, // still an unclaimed dispatch offer
    BookingStatus.rejected,
    BookingStatus.expired,
    BookingStatus.cancelled,
    BookingStatus.paymentFailed,
    BookingStatus.completed,
  };

  static const _terminalStatuses = {
    BookingStatus.rejected,
    BookingStatus.expired,
    BookingStatus.cancelled,
    BookingStatus.paymentFailed,
    BookingStatus.completed,
  };

  @override
  Future<Result<List<BookingSubmissionResult>>> getDriverActiveAssignments({
    required String driverId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 120));
    final active = _submissionResults.values
        .where(
          (r) =>
              r.chauffeurId == driverId &&
              !_nonActiveStatuses.contains(r.status),
        )
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return Result.success(active);
  }

  @override
  Future<Result<List<BookingSubmissionResult>>> getDispatchMonitorBookings() async {
    await Future.delayed(const Duration(milliseconds: 120));
    final monitor = _submissionResults.values
        .where((r) => !_terminalStatuses.contains(r.status))
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return Result.success(monitor);
  }

  /// Transitions a driver-side trip milestone on the booking record.
  ///
  /// Called by the trip controller on stage changes (en route, arrived,
  /// ceremony started) so the admin dispatch monitor and driver dashboard
  /// reflect the live ceremony stage. Completed bookings are never reverted.
  void updateBookingStage(String bookingId, BookingStatus status) {
    final existing = _submissionResults[bookingId];
    if (existing == null || existing.status == BookingStatus.completed) {
      return;
    }
    _submissionResults[bookingId] = BookingSubmissionResult(
      bookingId: existing.bookingId,
      bookingReference: existing.bookingReference,
      status: status,
      submittedAt: existing.submittedAt,
      vehicleId: existing.vehicleId,
      vehicleName: existing.vehicleName,
      vehicleClass: existing.vehicleClass,
      chauffeurId: existing.chauffeurId,
      ceremonyType: existing.ceremonyType,
      ceremonialAttire: existing.ceremonialAttire,
      serviceStartDateTime: existing.serviceStartDateTime,
      serviceEndDateTime: existing.serviceEndDateTime,
      routeDistanceKm: existing.routeDistanceKm,
      pickupAddress: existing.pickupAddress,
      destinationAddress: existing.destinationAddress,
      primaryContactName: existing.primaryContactName,
      primaryContactPhone: existing.primaryContactPhone,
      estimatedTotalPaise: existing.estimatedTotalPaise,
      advanceTokenPaise: existing.advanceTokenPaise,
      advanceTokenLabel: existing.advanceTokenLabel,
      nextStepMessage: existing.nextStepMessage,
      isIdempotentReplay: existing.isIdempotentReplay,
    );
  }

  /// Admin dispatch override: marks an emergency standby chauffeur as
  /// dispatched for a booking (PRD: emergency SOS / manual overrides).
  ///
  /// Only allowed for bookings awaiting chauffeur acceptance. Returns the
  /// authoritative updated record.
  Result<BookingSubmissionResult> dispatchEmergencyReplacement({
    required String bookingId,
    required String driverId,
  }) {
    final existing = _submissionResults[bookingId];
    if (existing == null) {
      return Result.failure(
        NotFoundFailure('Booking not found for ID: $bookingId'),
      );
    }
    if (existing.status != BookingStatus.requested) {
      return Result.failure(
        ConflictFailure(
          'Emergency dispatch is only available for bookings awaiting acceptance.',
        ),
      );
    }

    final emergencyResult = BookingSubmissionResult(
      bookingId: existing.bookingId,
      bookingReference: existing.bookingReference,
      status: BookingStatus.emergencyReplacement,
      submittedAt: existing.submittedAt,
      vehicleId: existing.vehicleId,
      vehicleName: existing.vehicleName,
      vehicleClass: existing.vehicleClass,
      chauffeurId: driverId,
      ceremonyType: existing.ceremonyType,
      ceremonialAttire: existing.ceremonialAttire,
      serviceStartDateTime: existing.serviceStartDateTime,
      serviceEndDateTime: existing.serviceEndDateTime,
      routeDistanceKm: existing.routeDistanceKm,
      pickupAddress: existing.pickupAddress,
      destinationAddress: existing.destinationAddress,
      primaryContactName: existing.primaryContactName,
      primaryContactPhone: existing.primaryContactPhone,
      estimatedTotalPaise: existing.estimatedTotalPaise,
      advanceTokenPaise: existing.advanceTokenPaise,
      advanceTokenLabel: existing.advanceTokenLabel,
      nextStepMessage:
          'Emergency standby chauffeur dispatched by operations.',
    );
    _submissionResults[bookingId] = emergencyResult;

    onLifecycleEvent?.call(
      title: 'Emergency Standby Dispatched',
      body:
          'Operations dispatched an emergency standby chauffeur for '
          '${emergencyResult.bookingReference}.',
    );

    return Result.success(emergencyResult);
  }

  /// Marks a booking as CONFIRMED after successful advance-token payment.
  ///
  /// Only transitions from DRIVER_ACCEPTED (or PAYMENT_PENDING) — mirrors the
  /// server state machine where the advance token locks the reservation.
  /// Available as a seam for the payment checkout flow and tests.
  void markBookingConfirmed(String bookingId) {
    final existing = _submissionResults[bookingId];
    if (existing != null &&
        (existing.status == BookingStatus.driverAccepted ||
            existing.status == BookingStatus.paymentPending)) {
      _submissionResults[bookingId] = BookingSubmissionResult(
        bookingId: existing.bookingId,
        bookingReference: existing.bookingReference,
        status: BookingStatus.confirmed,
        submittedAt: existing.submittedAt,
        vehicleId: existing.vehicleId,
        vehicleName: existing.vehicleName,
        vehicleClass: existing.vehicleClass,
        chauffeurId: existing.chauffeurId,
        ceremonyType: existing.ceremonyType,
        ceremonialAttire: existing.ceremonialAttire,
        serviceStartDateTime: existing.serviceStartDateTime,
        serviceEndDateTime: existing.serviceEndDateTime,
        routeDistanceKm: existing.routeDistanceKm,
        pickupAddress: existing.pickupAddress,
        destinationAddress: existing.destinationAddress,
        primaryContactName: existing.primaryContactName,
        primaryContactPhone: existing.primaryContactPhone,
        estimatedTotalPaise: existing.estimatedTotalPaise,
        advanceTokenPaise: existing.advanceTokenPaise,
        advanceTokenLabel: existing.advanceTokenLabel,
        nextStepMessage:
            'Advance token received. Your ceremonial reservation is officially secured.',
        isIdempotentReplay: existing.isIdempotentReplay,
      );

      onLifecycleEvent?.call(
        title: 'Reservation Secured',
        body:
            'Advance token received for ${existing.bookingReference}. '
            'Your ceremony is officially confirmed.',
      );
    }

    final summary = _bookings[bookingId];
    if (summary != null) {
      _bookings[bookingId] = BookingSummary(
        id: summary.id,
        reference: summary.reference,
        serviceCategory: summary.serviceCategory,
        status: 'CONFIRMED',
        eventStartTime: summary.eventStartTime,
        eventEndTime: summary.eventEndTime,
        pickupAddress: summary.pickupAddress,
        destinationAddress: summary.destinationAddress,
        routeDistanceKm: summary.routeDistanceKm,
        vehicleName: summary.vehicleName,
        chauffeurName: summary.chauffeurName,
        totalAmountCents: summary.totalAmountCents,
        advanceTokenCents: summary.advanceTokenCents,
        version: summary.version + 1,
      );
    }
  }

  /// Marks a booking as completed in the in-memory store.
  ///
  /// Called by [MockTripRepository.completeTrip] and available as a test seam
  /// for seeding completed assignment history.
  void markBookingCompleted(String bookingId) {
    final existing = _submissionResults[bookingId];
    if (existing != null) {
      _submissionResults[bookingId] = BookingSubmissionResult(
        bookingId: existing.bookingId,
        bookingReference: existing.bookingReference,
        status: BookingStatus.completed,
        submittedAt: existing.submittedAt,
        vehicleId: existing.vehicleId,
        vehicleName: existing.vehicleName,
        vehicleClass: existing.vehicleClass,
        chauffeurId: existing.chauffeurId,
        ceremonyType: existing.ceremonyType,
        ceremonialAttire: existing.ceremonialAttire,
        serviceStartDateTime: existing.serviceStartDateTime,
        serviceEndDateTime: existing.serviceEndDateTime,
        routeDistanceKm: existing.routeDistanceKm,
        pickupAddress: existing.pickupAddress,
        destinationAddress: existing.destinationAddress,
        primaryContactName: existing.primaryContactName,
        primaryContactPhone: existing.primaryContactPhone,
        estimatedTotalPaise: existing.estimatedTotalPaise,
        advanceTokenPaise: existing.advanceTokenPaise,
        advanceTokenLabel: existing.advanceTokenLabel,
        nextStepMessage: existing.nextStepMessage,
        isIdempotentReplay: existing.isIdempotentReplay,
      );
    }
    _completedBookings.add(bookingId);
  }

  @override
  Future<Result<BookingSubmissionResult>> getDriverBookingDetails({
    required String bookingId,
    required String driverId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final result = _submissionResults[bookingId];
    if (result == null) {
      return Result.failure(
        NotFoundFailure('Booking request not found for ID: $bookingId'),
      );
    }
    return Result.success(result);
  }

  @override
  Future<Result<BookingSubmissionResult>> acceptBooking({
    required String bookingId,
    required String driverId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final existing = _submissionResults[bookingId];
    if (existing == null) {
      return Result.failure(
        NotFoundFailure('Booking request not found for ID: $bookingId'),
      );
    }

    // Server-Authoritative Concurrency Invariant:
    // Only ONE driver can accept a given booking. If another driver already accepted,
    // or if the booking is not in REQUESTED status, reject with ConflictFailure.
    if (existing.status != BookingStatus.requested) {
      return Result.failure(
        const ConflictFailure(
          'This ceremonial reservation is no longer available. It has already been accepted by another chauffeur.',
        ),
      );
    }

    // Atomically transition status to DRIVER_ACCEPTED and bind chauffeur
    final acceptedResult = BookingSubmissionResult(
      bookingId: existing.bookingId,
      bookingReference: existing.bookingReference,
      status: BookingStatus.driverAccepted,
      submittedAt: existing.submittedAt,
      vehicleId: existing.vehicleId,
      vehicleName: existing.vehicleName,
      vehicleClass: existing.vehicleClass,
      chauffeurId: driverId,
      ceremonyType: existing.ceremonyType,
      ceremonialAttire: existing.ceremonialAttire,
      serviceStartDateTime: existing.serviceStartDateTime,
      serviceEndDateTime: existing.serviceEndDateTime,
      routeDistanceKm: existing.routeDistanceKm,
      pickupAddress: existing.pickupAddress,
      destinationAddress: existing.destinationAddress,
      primaryContactName: existing.primaryContactName,
      primaryContactPhone: existing.primaryContactPhone,
      estimatedTotalPaise: existing.estimatedTotalPaise,
      advanceTokenPaise: existing.advanceTokenPaise,
      advanceTokenLabel: existing.advanceTokenLabel,
      nextStepMessage:
          'Chauffeur offer confirmed. Customer will proceed with advance token lock.',
      isIdempotentReplay: false,
    );

    _submissionResults[bookingId] = acceptedResult;

    // Lifecycle event → notification center (best-effort).
    onLifecycleEvent?.call(
      title: 'Offer Accepted',
      body:
          'Chauffeur accepted ceremonial offer ${acceptedResult.bookingReference}. '
          'The host can now complete the advance token.',
    );

    // Update synchronized booking summary
    final existingSummary = _bookings[bookingId];
    if (existingSummary != null) {
      _bookings[bookingId] = BookingSummary(
        id: existingSummary.id,
        reference: existingSummary.reference,
        serviceCategory: existingSummary.serviceCategory,
        status: 'DRIVER_ACCEPTED',
        eventStartTime: existingSummary.eventStartTime,
        eventEndTime: existingSummary.eventEndTime,
        pickupAddress: existingSummary.pickupAddress,
        totalAmountCents: existingSummary.totalAmountCents,
        advanceTokenCents: existingSummary.advanceTokenCents,
        version: existingSummary.version + 1,
      );
    }

    return Result.success(acceptedResult);
  }

  @override
  Future<Result<void>> declineBooking({
    required String bookingId,
    required String driverId,
    required DriverDeclineReason reason,
    String? notes,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final existing = _submissionResults[bookingId];
    if (existing == null) {
      return Result.failure(
        NotFoundFailure('Booking request not found for ID: $bookingId'),
      );
    }

    _driverDeclines.putIfAbsent(driverId, () => <String>{}).add(bookingId);
    return const Result.success(null);
  }

  @override
  Future<Result<FleetAvailabilityResult>> checkFleetAvailability(
    CustomerFleetIntent intent,
  ) async {
    await Future.delayed(const Duration(milliseconds: 100));

    if (intent.preference == CustomerFleetPreference.preferredModel) {
      final model = intent.preferredModel ?? 'Toyota Innova Crysta';
      final requestedCount =
          intent.requestedUnits[model] ?? (intent.passengerCount / 6).ceil();
      final availableCount = _mockInventory[model] ?? 2;

      if (requestedCount <= availableCount) {
        return Result.success(
          FleetAvailabilityResult.available(
            model: model,
            count: requestedCount,
          ),
        );
      } else {
        final shortfall = requestedCount - availableCount;
        // Find alternative suggestions to cover shortfall without silent substitution
        final alternatives = <FleetAlternativeSuggestion>[];
        for (final entry in _mockInventory.entries) {
          if (entry.key != model && entry.value >= shortfall) {
            alternatives.add(
              FleetAlternativeSuggestion(
                modelName: entry.key,
                suggestedCount: shortfall,
                capacityPerUnit: _modelCapacity[entry.key] ?? 4,
                rationale:
                    'Premium luxury vehicle available to fulfill capacity requirement without ceremony disruption.',
              ),
            );
          }
        }
        if (alternatives.isEmpty) {
          alternatives.add(
            const FleetAlternativeSuggestion(
              modelName: 'Toyota Camry',
              suggestedCount: 2,
              capacityPerUnit: 4,
              rationale: 'Complementary executive fleet option.',
            ),
          );
        }

        return Result.success(
          FleetAvailabilityResult.partial(
            model: model,
            requestedCount: requestedCount,
            availableCount: availableCount,
            alternativeSuggestions: alternatives,
          ),
        );
      }
    } else if (intent.preference == CustomerFleetPreference.customFleet) {
      // Check each requested unit
      bool anyShortfall = false;
      int totalRequested = 0;
      int totalAvailable = 0;
      final alternatives = <FleetAlternativeSuggestion>[];

      for (final entry in intent.requestedUnits.entries) {
        final model = entry.key;
        final requested = entry.value;
        final available = _mockInventory[model] ?? 2;
        totalRequested += requested;
        totalAvailable += (requested <= available ? requested : available);

        if (requested > available) {
          anyShortfall = true;
          final diff = requested - available;
          alternatives.add(
            FleetAlternativeSuggestion(
              modelName: 'Toyota Camry',
              suggestedCount: diff,
              capacityPerUnit: 4,
              rationale: 'Substitute option for unavailable $model unit(s).',
            ),
          );
        }
      }

      if (!anyShortfall) {
        return Result.success(
          FleetAvailabilityResult(
            isFullyAvailable: true,
            requestedCount: totalRequested,
            availableCount: totalRequested,
            shortfall: 0,
            message:
                'Custom ceremonial fleet composition is confirmed and available.',
          ),
        );
      } else {
        final shortfall = totalRequested - totalAvailable;
        return Result.success(
          FleetAvailabilityResult(
            isFullyAvailable: false,
            requestedCount: totalRequested,
            availableCount: totalAvailable,
            shortfall: shortfall,
            alternativeSuggestions: alternatives,
            message:
                'Partial fleet available ($totalAvailable of $totalRequested units). Review suggested alternatives.',
          ),
        );
      }
    } else {
      // anySuitable
      final requestedCount = (intent.passengerCount / 4).ceil();
      return Result.success(
        FleetAvailabilityResult.available(
          model: 'Mixed Luxury Fleet',
          count: requestedCount,
        ),
      );
    }
  }

  @override
  Future<Result<GroupBooking>> submitGroupBooking(
    GroupBookingSubmissionRequest request,
  ) async {
    await Future.delayed(const Duration(milliseconds: 150));

    // Idempotency check
    final existing = _idempotentGroupSubmissions[request.idempotencyKey];
    if (existing != null) {
      return Result.success(existing);
    }

    final parentBookingId = 'grp_${_groupCounter++}';
    final bookingReference = 'SD-GRP-2026-00$_groupCounter';
    final assignments = <VehicleAssignment>[];
    int assignmentSeq = 1;

    final unitsMap = request.fleetIntent.requestedUnits.isNotEmpty
        ? request.fleetIntent.requestedUnits
        : (request.fleetIntent.preferredModel != null
              ? {
                  request.fleetIntent.preferredModel!:
                      (request.fleetIntent.passengerCount / 6).ceil(),
                }
              : {
                  'Toyota Innova Crysta':
                      (request.fleetIntent.passengerCount / 6).ceil(),
                });

    int estimatedTotalPaise = 0;

    unitsMap.forEach((model, count) {
      for (var i = 1; i <= count; i++) {
        final assignmentId = 'asgn_${parentBookingId}_$assignmentSeq';
        final capacity = _modelCapacity[model] ?? 4;
        final price = _modelPricePaise[model] ?? 2500000;
        estimatedTotalPaise += price;

        assignments.add(
          VehicleAssignment(
            assignmentId: assignmentId,
            parentBookingId: parentBookingId,
            vehicleId: 'veh_${model.replaceAll(' ', '_').toLowerCase()}_$i',
            vehicleName: '$model #$i',
            vehicleModel: model,
            capacity: capacity,
            ownerName: 'PB Ceremonial Fleet',
            chauffeurId: 'drv_$assignmentSeq',
            chauffeurName: 'Chauffeur Unit $assignmentSeq',
            pricePaise: price,
            status: 'ASSIGNED',
          ),
        );
        assignmentSeq++;
      }
    });

    final advanceTokenPaise = (estimatedTotalPaise * 0.20).round();

    final groupBooking = GroupBooking(
      parentBookingId: parentBookingId,
      bookingReference: bookingReference,
      status: BookingStatus.requested,
      customerIntent: request.fleetIntent,
      totalPassengers: request.fleetIntent.passengerCount,
      totalVehicles: assignments.length,
      assignments: assignments,
      ceremonyType: request.ceremonyType,
      serviceStartDateTime: request.serviceStartDateTime,
      serviceEndDateTime: request.serviceEndDateTime,
      city: request.city,
      pickupAddress: request.pickupAddress,
      destinationAddress: request.destinationAddress,
      primaryContactName: request.primaryContactName,
      primaryContactPhone: request.primaryContactPhone,
      estimatedTotalPaise: estimatedTotalPaise,
      advanceTokenPaise: advanceTokenPaise,
      advanceTokenLabel: 'Advance Token (20%)',
      createdAt: DateTime.now(),
    );

    _groupBookings[parentBookingId] = groupBooking;
    _idempotentGroupSubmissions[request.idempotencyKey] = groupBooking;

    return Result.success(groupBooking);
  }

  @override
  Future<Result<GroupBooking?>> getGroupBooking(String parentBookingId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return Result.success(_groupBookings[parentBookingId]);
  }
}
