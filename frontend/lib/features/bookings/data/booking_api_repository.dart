import 'package:dio/dio.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/result/result.dart';
import '../../drivers/domain/entities/driver_decline_reason.dart';
import '../../search/domain/entities/trip_type.dart';
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
import '../domain/policies/service_category_policy.dart';
import '../domain/repositories/booking_repository.dart';
import 'dto/submit_booking_dto.dart';

/// Real backend booking repository.
///
/// Drafts remain device-local (there is intentionally no draft table in the
/// backend — drafts are unfinished customer intent). Submissions, lifecycle
/// transitions, driver offers, availability, and group bookings are fully
/// server-authoritative. Pricing sent to the server is advisory; the backend
/// recalculates from its own pricing rules and persists ITS numbers.
class BookingApiRepository implements BookingRepository {
  final ApiClient _client;

  /// In-session draft store (drafts are local-first by design).
  final Map<String, BookingDraft> _drafts = {};

  BookingApiRepository(this._client);

  // ------------------------------------------------------------------
  // Drafts (local-first)
  // ------------------------------------------------------------------

  @override
  Future<Result<BookingDraft>> createBookingDraft(BookingDraft draft) async {
    _drafts[draft.id] = draft;
    return Result.success(draft);
  }

  @override
  Future<Result<BookingDraft?>> getBookingDraft(String draftId) async {
    return Result.success(_drafts[draftId]);
  }

  @override
  Future<Result<void>> saveBookingDraft(BookingDraft draft) async {
    _drafts[draft.id] = draft;
    return const Result.success(null);
  }

  // ------------------------------------------------------------------
  // Submission (idempotent, server-priced)
  // ------------------------------------------------------------------

  @override
  Future<Result<BookingSubmissionResult>> submitBooking(
    BookingSubmissionRequest request,
  ) async {
    // Build the canonical payload first and refuse locally when it violates the
    // backend's own declared rules. The app never spends a request the server
    // is guaranteed to answer with VALIDATION_FAILED, and the customer gets the
    // precise field to fix rather than an opaque rejection.
    final dto = SubmitBookingDto.fromDomain(
      request,
      serviceCategoryId: ServiceCategoryPolicy.forCeremony(request.ceremonyType),
    );
    final violation = dto.firstContractViolation();
    if (violation != null) {
      return Result.failure(
        ValidationFailure(violation, code: 'INVALID_BOOKING_DRAFT'),
      );
    }

    try {
      final response = await _client.post<Map<String, dynamic>>(
        '${AppConstants.apiV1Prefix}/bookings',
        data: dto.toJson(),
        options: _idempotencyHeader(request.idempotencyKey),
      );
      final envelope = ApiEnvelope.fromJson(response.data);
      final data = (envelope.data as Map<String, dynamic>?) ?? const {};
      final booking = (data['booking'] as Map<String, dynamic>?) ?? const {};
      final replay = data['idempotent_replay'] == true;
      return Result.success(
        _submissionResultFromServer(booking, request, replay),
      );
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  Options _idempotencyHeader(String key) =>
      Options(headers: {'Idempotency-Key': key});

  /// Server booking response → domain result. The server answers with the
  /// CUSTOMER privacy view (snake_case: no idempotency key, no OTP hash), so
  /// every field prefers the customer-view name and falls back to the legacy
  /// raw-row camelCase spelling. Vehicle display fields come from the client
  /// request (server stores vehicleFk; display strings are presentation).
  BookingSubmissionResult _submissionResultFromServer(
    Map<String, dynamic> booking,
    BookingSubmissionRequest request,
    bool replay,
  ) {
    return BookingSubmissionResult(
      bookingId: (booking['id'] as String?) ?? '',
      bookingReference:
          (booking['reference_code'] as String?) ??
              (booking['referenceCode'] as String?) ??
              '',
      status: _statusFromWire(booking['status'] as String?),
      submittedAt: parseDateTime(
        booking['submitted_at'] ??
            booking['submittedAt'] ??
            booking['service_start_time'],
      ),
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
      // SERVER-AUTHORITATIVE amounts — never echo the client's numbers.
      estimatedTotalPaise: parseIntAmount(
        booking['estimated_total_paise'] ?? booking['estimatedTotalPaise'],
      ),
      advanceTokenPaise: parseIntAmount(
        booking['advance_token_paise'] ?? booking['advanceTokenPaise'],
      ),
      advanceTokenLabel:
          (booking['advanceTokenLabel'] as String?) ?? request.advanceTokenLabel,
      nextStepMessage: replay
          ? 'Existing booking returned (idempotent replay).'
          : 'Request submitted. ShadiDriver operations will review your fleet and confirm.',
      isIdempotentReplay: replay,
    );
  }

  @override
  Future<Result<BookingSubmissionResult?>> getSubmissionResult(
    String bookingId,
  ) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '${AppConstants.apiV1Prefix}/bookings/$bookingId');
      final envelope = ApiEnvelope.fromJson(response.data);
      final booking = (envelope.data as Map<String, dynamic>?) ?? const {};
      return Result.success(_resultFromRow(booking));
    } catch (e) {
      final failure = mapDioError(e);
      if (failure.code == 'NOT_FOUND') return const Result.success(null);
      return Result.failure(failure);
    }
  }

  // ------------------------------------------------------------------
  // Queries
  // ------------------------------------------------------------------

  @override
  Future<Result<BookingSummary>> getBookingById(String bookingId) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '${AppConstants.apiV1Prefix}/bookings/$bookingId');
      final envelope = ApiEnvelope.fromJson(response.data);
      final booking = (envelope.data as Map<String, dynamic>?) ?? const {};
      return Result.success(_summaryFromRow(booking));
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  @override
  Future<Result<List<BookingSummary>>> getMyBookings({
    int page = 1,
    int limit = 20,
    String? statusFilter,
  }) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '${AppConstants.apiV1Prefix}/bookings/my',
        queryParameters: {'page': page, 'limit': limit},
      );
      final envelope = ApiEnvelope.fromJson(response.data);
      final data = (envelope.data as Map<String, dynamic>?) ?? const {};
      final items = (data['items'] as List?) ?? const [];
      return Result.success(
        items.whereType<Map<String, dynamic>>().map(_summaryFromRow).toList(),
      );
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  // ------------------------------------------------------------------
  // Lifecycle transitions
  // ------------------------------------------------------------------

  @override
  Future<Result<BookingSummary>> transitionState({
    required String bookingId,
    required String action,
    required int currentVersion,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '${AppConstants.apiV1Prefix}/bookings/$bookingId/transition',
        data: {
          'action': action,
          ...?metadata?['otp'] != null ? {'otp': metadata!['otp']} : null,
          ...?metadata?['reason'] != null ? {'reason': metadata!['reason']} : null,
        },
      );
      final envelope = ApiEnvelope.fromJson(response.data);
      final booking = (envelope.data as Map<String, dynamic>?) ?? const {};
      return Result.success(_summaryFromRow(booking));
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  @override
  Future<Result<void>> cancelBooking({
    required String bookingId,
    required String reason,
  }) async {
    try {
      await _client.post<Map<String, dynamic>>(
        '${AppConstants.apiV1Prefix}/bookings/$bookingId/transition',
        data: {'action': 'CANCEL', 'reason': reason},
      );
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  // ------------------------------------------------------------------
  // Driver offers / assignments
  // ------------------------------------------------------------------

  @override
  Future<Result<List<BookingSubmissionResult>>> getDriverBookingRequests({
    required String driverId,
  }) async {
    try {
      final data = await _driverOffers();
      // No marketplace: the backend always returns `offers: []`. The wire key
      // survives only for wire-compat — the duty list lives under
      // `assignments` (operations-allocated work).
      return Result.success(
        (data['offers'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(_resultFromRow)
            .toList(),
      );
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  @override
  Future<Result<List<BookingSubmissionResult>>> getCompletedBookings({
    required String driverId,
  }) async {
    try {
      final data = await _driverOffers();
      return Result.success(
        (data['completed'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(_resultFromRow)
            .toList(),
      );
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  @override
  Future<Result<List<BookingSubmissionResult>>> getDriverActiveAssignments({
    required String driverId,
  }) async {
    try {
      final data = await _driverOffers();
      // `assignments` = operations-allocated duties (the real wire);
      // `active` kept as a legacy fallback key.
      final rows = (data['assignments'] as List?) ??
          (data['active'] as List?) ??
          const [];
      return Result.success(
        rows.whereType<Map<String, dynamic>>().map(_resultFromRow).toList(),
      );
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  /// Dispatch monitor merges all open offers + live assignments fleet-wide.
  @override
  Future<Result<List<BookingSubmissionResult>>> getDispatchMonitorBookings() async {
    try {
      final data = await _driverOffers();
      final all = <Map<String, dynamic>>[
        ...(data['offers'] as List? ?? const []).whereType<Map<String, dynamic>>(),
        ...((data['assignments'] as List?) ??
                (data['active'] as List?) ??
                const [])
            .whereType<Map<String, dynamic>>(),
      ];
      return Result.success(all.map(_resultFromRow).toList());
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  Future<Map<String, dynamic>> _driverOffers() async {
    final response = await _client.get<Map<String, dynamic>>(
        '${AppConstants.apiV1Prefix}/bookings/driver/offers');
    final envelope = ApiEnvelope.fromJson(response.data);
    return (envelope.data as Map<String, dynamic>?) ?? const {};
  }

  @override
  Future<Result<BookingSubmissionResult>> getDriverBookingDetails({
    required String bookingId,
    required String driverId,
  }) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '${AppConstants.apiV1Prefix}/bookings/$bookingId');
      final envelope = ApiEnvelope.fromJson(response.data);
      final booking = (envelope.data as Map<String, dynamic>?) ?? const {};
      return Result.success(_resultFromRow(booking));
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  /// There is deliberately NO accept endpoint: ShadiDriver operations
  /// allocates chauffeurs (`POST /bookings/:id/assign-chauffeur`, admin-only)
  /// and the duty appears already assigned. A claim attempt is refused
  /// locally rather than faked against a marketplace that does not exist.
  @override
  Future<Result<BookingSubmissionResult>> acceptBooking({
    required String bookingId,
    required String driverId,
  }) async {
    return Result.failure(
      const ValidationFailure(
        'Duties are allocated by ShadiDriver operations — there is no booking to claim.',
        code: 'NOT_SUPPORTED',
      ),
    );
  }

  /// Report a conflict on an ASSIGNED duty → the duty returns to the
  /// operations queue (reassignment). This is the only driver-side "decline"
  /// that exists — never a marketplace decline of a customer request.
  @override
  Future<Result<void>> declineBooking({
    required String bookingId,
    required String driverId,
    required DriverDeclineReason reason,
    String? notes,
  }) async {
    try {
      final payload = <String, dynamic>{'reason': reason.code};
      if (notes != null) payload['notes'] = notes;
      await _client.post<Map<String, dynamic>>(
        '${AppConstants.apiV1Prefix}/bookings/$bookingId/assignment-conflict',
        data: payload,
      );
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  // ------------------------------------------------------------------
  // Fleet availability + group bookings
  // ------------------------------------------------------------------

  @override
  Future<Result<FleetAvailabilityResult>> checkFleetAvailability(
    CustomerFleetIntent intent, {
    DateTime? serviceStartTime,
    DateTime? serviceEndTime,
    String? city,
    TripType tripType = TripType.oneWay,
  }) async {
    try {
      final fleet = intent.requestedUnits.entries
          .map((e) => {'vehicleTypeId': e.key, 'quantity': e.value})
          .toList();
      final response = await _client.post<Map<String, dynamic>>(
        '${AppConstants.apiV1Prefix}/availability/fleet',
        data: {
          'fleet': fleet,
          'serviceStartTime':
              (serviceStartTime ?? DateTime.now().toUtc()).toIso8601String(),
          'serviceEndTime': (serviceEndTime ??
                  (serviceStartTime ?? DateTime.now()).add(const Duration(hours: 8)))
              .toIso8601String(),
          'city': city,
          // Echoed by the server; overlap conflicts use the full window.
          'tripType': tripType.wire,
        },
      );
      final envelope = ApiEnvelope.fromJson(response.data);
      final data = (envelope.data as Map<String, dynamic>?) ?? const {};
      return Result.success(_fleetResultFromServer(data, intent));
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  FleetAvailabilityResult _fleetResultFromServer(
    Map<String, dynamic> data,
    CustomerFleetIntent intent,
  ) {
    final lines = (data['lines'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    if (lines.length == 1) {
      final line = lines.first;
      final requested = (line['requested'] as num?)?.toInt() ?? 0;
      final available = (line['available'] as num?)?.toInt() ?? 0;
      final model = (line['display_name'] as String?) ?? intent.preferredModel ?? '';
      if ((line['shortfall'] as num? ?? 0) == 0) {
        return FleetAvailabilityResult.available(model: model, count: available);
      }
      return FleetAvailabilityResult.partial(
        model: model,
        requestedCount: requested,
        availableCount: available,
        alternativeSuggestions: _alternativesFrom(line),
      );
    }
    // Mixed fleet: aggregate; partial when ANY line has shortfall.
    final requestedTotal = (data['total_requested'] as num?)?.toInt() ?? 0;
    final availableTotal = (data['total_available'] as num?)?.toInt() ?? 0;
    final shortfallLines =
        lines.where((l) => (l['shortfall'] as num? ?? 0) > 0).toList();
    if (shortfallLines.isEmpty) {
      return FleetAvailabilityResult.available(count: availableTotal);
    }
    return FleetAvailabilityResult.partial(
      model: shortfallLines
          .map((l) => (l['display_name'] as String?) ?? '')
          .join(', '),
      requestedCount: requestedTotal,
      availableCount: availableTotal,
      alternativeSuggestions: [
        for (final line in shortfallLines) ..._alternativesFrom(line),
      ],
    );
  }

  List<FleetAlternativeSuggestion> _alternativesFrom(Map<String, dynamic> line) {
    return ((line['alternatives'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((a) => FleetAlternativeSuggestion(
              modelName: (a['display_name'] as String?) ?? '',
              suggestedCount: (a['available'] as num?)?.toInt() ?? 0,
              capacityPerUnit: (a['seating_capacity'] as num?)?.toInt() ?? 0,
              rationale: 'Available alternative with verified chauffeur fleet.',
            ))
        .toList();
  }

  @override
  Future<Result<GroupBooking>> submitGroupBooking(
    GroupBookingSubmissionRequest request,
  ) async {
    try {
      final fleet = request.fleetIntent.requestedUnits.entries
          .map((e) => {'vehicleTypeId': e.key, 'quantity': e.value})
          .toList();
      final response = await _client.post<Map<String, dynamic>>(
        '${AppConstants.apiV1Prefix}/group-bookings',
        data: {
          'serviceCategoryId': ServiceCategoryPolicy.forCeremony(
            request.ceremonyType,
          ),
          'ceremonyType': request.ceremonyType,
          'city': request.city,
          'pickupAddress': request.pickupAddress,
          'destinationAddress': request.destinationAddress,
          'serviceStartTime': request.serviceStartDateTime.toIso8601String(),
          'serviceEndTime': request.serviceEndDateTime.toIso8601String(),
          'primaryContactName': request.primaryContactName,
          'primaryContactPhone': request.primaryContactPhone,
          'passengerCount': request.fleetIntent.passengerCount,
          // Persisted and baked into the pricing snapshot server-side
          // (ROUND_TRIP halves per-vehicle included km on package tariffs).
          'tripType': request.tripType.wire,
          'fleet': fleet,
          'idempotencyKey': request.idempotencyKey,
          if (request.requirements.isNotEmpty)
            'requirements': request.requirements,
          'communicationPreference': request.communicationPreference,
        },
      );
      final envelope = ApiEnvelope.fromJson(response.data);
      final data = (envelope.data as Map<String, dynamic>?) ?? const {};
      final group = (data['groupBooking'] as Map<String, dynamic>?) ?? const {};
      return Result.success(_groupFromServer(group));
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  @override
  Future<Result<GroupBooking?>> getGroupBooking(String parentBookingId) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '${AppConstants.apiV1Prefix}/group-bookings/$parentBookingId',
      );
      final envelope = ApiEnvelope.fromJson(response.data);
      final group = (envelope.data as Map<String, dynamic>?) ?? const {};
      if (group.isEmpty) return const Result.success(null);
      return Result.success(_groupFromServer(group));
    } catch (e) {
      final failure = mapDioError(e);
      if (failure.code == 'NOT_FOUND') return const Result.success(null);
      return Result.failure(failure);
    }
  }

  /// Maps the CUSTOMER group-booking payload.
  ///
  /// The wire format is snake_case and deliberately narrow: it carries the
  /// customer's own booking plus a neutral `chauffeur_assigned` flag. Partner
  /// identity, registration plates and chauffeur names are internal operational
  /// data that the backend does not send — this mapper must never expect them,
  /// and never invent a price of 0 for a booking that has not been quoted.
  GroupBooking _groupFromServer(Map<String, dynamic> group) {
    final assignmentsRaw =
        (group['assignments'] as List? ?? const []).whereType<Map<String, dynamic>>();
    final assignments = assignmentsRaw.map((a) {
      final vehicle = (a['vehicle'] as Map<String, dynamic>?) ?? const {};
      return VehicleAssignment(
        assignmentId: (a['id'] as String?) ?? '',
        parentBookingId: (group['id'] as String?) ?? '',
        vehicleId: (vehicle['id'] as String?) ?? '',
        vehicleName:
            '${vehicle['display_name'] ?? ''} ${vehicle['fleet_code'] ?? ''}'.trim(),
        vehicleModel: (a['requested_model'] as String?) ??
            (vehicle['display_name'] as String?) ??
            '',
        capacity: (a['seating_capacity'] as num?)?.toInt() ?? 0,
        // No partner/owner identity in a customer payload, by design.
        ownerName: '',
        chauffeurAssigned: a['chauffeur_assigned'] == true,
        pricePaise: parseIntAmountOrNull(a['estimated_total_paise']),
        status: (a['service_state'] as String?) ?? 'BEING_PREPARED',
      );
    }).toList();

    // Reconstruct the requested fleet from the server's own intent record when
    // present, falling back to the allocated assignments.
    final units = <String, int>{};
    final requested = (group['requested_fleet'] as List? ?? const [])
        .whereType<Map<String, dynamic>>();
    for (final line in requested) {
      final name =
          (line['vehicle_class'] as String?) ?? (line['vehicleTypeId'] as String?) ?? '';
      final qty = (line['quantity'] as num?)?.toInt() ?? 0;
      if (name.isNotEmpty && qty > 0) units[name] = (units[name] ?? 0) + qty;
    }
    if (units.isEmpty) {
      for (final a in assignments) {
        units[a.vehicleModel] = (units[a.vehicleModel] ?? 0) + 1;
      }
    }

    return GroupBooking(
      parentBookingId: (group['id'] as String?) ?? '',
      bookingReference: (group['reference_code'] as String?) ?? '',
      status: _statusFromWire(group['status'] as String?),
      customerIntent: CustomerFleetIntent.mixed(
        passengerCount: (group['passenger_count'] as num?)?.toInt() ?? 0,
        units: units,
      ),
      totalPassengers: (group['passenger_count'] as num?)?.toInt() ?? 0,
      totalVehicles: assignments.length,
      assignments: assignments,
      ceremonyType: (group['ceremony_type'] as String?) ?? '',
      serviceStartDateTime: parseDateTime(group['service_start_time']),
      serviceEndDateTime: parseDateTime(group['service_end_time']),
      city: (group['city'] as String?) ?? '',
      pickupAddress: (group['pickup_address'] as String?) ?? '',
      destinationAddress: (group['destination_address'] as String?) ?? '',
      estimatedTotalPaise: parseIntAmountOrNull(group['estimated_total_paise']),
      advanceTokenPaise: parseIntAmountOrNull(group['advance_token_paise']),
      requirements: (group['requirements'] as List? ?? const [])
          .whereType<String>()
          .toList(),
      communicationPreference:
          (group['communication_preference'] as String?) ?? 'PHONE',
      version: (group['version'] as num?)?.toInt() ?? 1,
      createdAt: parseDateTime(group['created_at']),
    );
  }

  // ------------------------------------------------------------------
  // Shared row mappers
  // ------------------------------------------------------------------

  BookingStatus _statusFromWire(String? wire) => switch ((wire ?? '').toUpperCase()) {
    'DRAFT' => BookingStatus.requested,
    'REQUESTED' => BookingStatus.requested,
    'UNDER_REVIEW' => BookingStatus.underReview,
    'VEHICLE_OPTIONS_PREPARED' => BookingStatus.vehicleOptionsPrepared,
    'CUSTOMER_CONFIRMATION_PENDING' => BookingStatus.customerConfirmationPending,
    'DRIVER_ACCEPTED' => BookingStatus.driverAccepted,
    'CONFIRMED' => BookingStatus.confirmed,
    'EN_ROUTE' => BookingStatus.driverArriving,
    'ARRIVED' => BookingStatus.arrived,
    'IN_PROGRESS' => BookingStatus.tripStarted,
    'COMPLETED' => BookingStatus.completed,
    'CANCELLED' => BookingStatus.cancelled,
    'PAYMENT_PENDING' => BookingStatus.paymentPending,
    'PAYMENT_FAILED' => BookingStatus.paymentFailed,
    'EXPIRED' => BookingStatus.expired,
    _ => BookingStatus.requested,
  };

  /// Row → summary.
  ///
  /// `GET /bookings/:id` is role-scoped server-side and serializes as a
  /// snake_case privacy DTO (customer/driver/admin views), while legacy rows
  /// (mock mode, older endpoints) are camelCase — every field falls back
  /// across both naming styles.
  BookingSummary _summaryFromRow(Map<String, dynamic> b) => BookingSummary(
        id: (b['id'] as String?) ?? '',
        reference:
            (b['referenceCode'] as String?) ??
                (b['reference_code'] as String?) ??
                '',
        serviceCategory:
            ((b['serviceCategory'] as Map<String, dynamic>?)?['title'] as String?) ??
                (b['serviceCategoryId'] as String?) ??
                (b['ceremony_type'] as String?) ??
                '',
        status: parseBookingStatusWire(b['status'] as String?),
        eventStartTime:
            parseDateTime(b['serviceStartTime'] ?? b['service_start_time']),
        eventEndTime:
            parseDateTime(b['serviceEndTime'] ?? b['service_end_time']),
        pickupAddress:
            (b['pickupAddress'] as String?) ??
                (b['pickup_address'] as String?) ??
                '',
        destinationAddress:
            (b['destinationAddress'] as String?) ??
                (b['destination_address'] as String?) ??
                '',
        routeDistanceKm:
            _doubleFromDecimal(b['routeDistanceKm'] ?? b['route_distance_km']),
        vehicleName:
            (b['vehicle_name'] as String?) ?? (b['vehicleId'] as String?) ?? '',
        // The customer view NEVER decodes chauffeur identity. This mapper
        // feeds every CUSTOMER booking surface, so even a payload that still
        // carried a driver object (a server regression, a legacy row) cannot
        // smuggle a name into the presentation layer. The chauffeur's own
        // duty view is a separate mapper (_resultFromRow).
        chauffeurName: '',
        chauffeurVerification:
            (b['chauffeur_verification'] as String?) ?? '',
        totalAmountCents:
            parseIntAmount(b['estimatedTotalPaise'] ?? b['estimated_total_paise']),
        advanceTokenCents:
            parseIntAmount(b['advanceTokenPaise'] ?? b['advance_token_paise']),
        version: (b['version'] as num?)?.toInt() ?? 1,
      );

  /// Row → detailed result (driver duty view, admin view, legacy rows).
  BookingSubmissionResult _resultFromRow(Map<String, dynamic> b) {
    final driverUser =
        ((b['driver'] as Map<String, dynamic>?)?['user'] as Map<String, dynamic>?);
    return BookingSubmissionResult(
      bookingId: (b['id'] as String?) ?? '',
      bookingReference:
          (b['referenceCode'] as String?) ??
              (b['reference_code'] as String?) ??
              '',
      status: _statusFromWire(b['status'] as String?),
      submittedAt:
          parseDateTime(
              b['submittedAt'] ?? b['submitted_at'] ?? b['service_start_time']),
      vehicleId: (b['vehicleId'] as String?) ?? '',
      vehicleName:
          (b['vehicle_name'] as String?) ?? (b['vehicleId'] as String?) ?? '',
      vehicleClass: (b['vehicleTypeId'] as String?) ?? '',
      chauffeurId: (b['driverFk'] as String?) ?? '',
      ceremonyType:
          (b['ceremonyType'] as String?) ?? (b['ceremony_type'] as String?) ?? '',
      ceremonialAttire:
          (b['ceremonialAttire'] as String?) ??
              (b['ceremonial_attire'] as String?) ??
              '',
      serviceStartDateTime:
          parseDateTime(b['serviceStartTime'] ?? b['service_start_time']),
      serviceEndDateTime:
          parseDateTime(b['serviceEndTime'] ?? b['service_end_time']),
      routeDistanceKm:
          _doubleFromDecimal(b['routeDistanceKm'] ?? b['route_distance_km']),
      pickupAddress:
          (b['pickupAddress'] as String?) ??
              (b['pickup_address'] as String?) ??
              '',
      destinationAddress:
          (b['destinationAddress'] as String?) ??
              (b['destination_address'] as String?) ??
              '',
      primaryContactName:
          ((b['customer'] as Map<String, dynamic>?)?['fullName'] as String?) ??
              (b['primaryContactName'] as String?) ??
              (b['host_name'] as String?) ??
              '',
      primaryContactPhone:
          ((b['customer'] as Map<String, dynamic>?)?['phoneNumber'] as String?) ??
              (b['primaryContactPhone'] as String?) ??
              (b['host_phone'] as String?) ??
              '',
      estimatedTotalPaise:
          parseIntAmount(b['estimatedTotalPaise'] ?? b['estimated_total_paise']),
      advanceTokenPaise:
          parseIntAmount(b['advanceTokenPaise'] ?? b['advance_token_paise']),
      nextStepMessage: driverUser != null
          ? 'Chauffeur ${driverUser['fullName']} assigned.'
          : '',
    );
  }

  double? _doubleFromDecimal(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

}
