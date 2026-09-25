import 'package:dio/dio.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/result/result.dart';
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

  /// Server booking row → domain result. Vehicle display fields come from the
  /// client request (server stores vehicleFk; display strings are presentation).
  BookingSubmissionResult _submissionResultFromServer(
    Map<String, dynamic> booking,
    BookingSubmissionRequest request,
    bool replay,
  ) {
    return BookingSubmissionResult(
      bookingId: (booking['id'] as String?) ?? '',
      bookingReference: (booking['referenceCode'] as String?) ?? '',
      status: _statusFromWire(booking['status'] as String?),
      submittedAt: parseDateTime(booking['submittedAt']),
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
      estimatedTotalPaise:
          parseIntAmount(booking['estimatedTotalPaise']),
      advanceTokenPaise: parseIntAmount(booking['advanceTokenPaise']),
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
      return Result.success(
        (data['active'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(_resultFromRow)
            .toList(),
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
        ...(data['active'] as List? ?? const []).whereType<Map<String, dynamic>>(),
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

  @override
  Future<Result<BookingSubmissionResult>> acceptBooking({
    required String bookingId,
    required String driverId,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '${AppConstants.apiV1Prefix}/bookings/$bookingId/accept',
      );
      final envelope = ApiEnvelope.fromJson(response.data);
      final booking = (envelope.data as Map<String, dynamic>?) ?? const {};
      return Result.success(_resultFromRow(booking));
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  @override
  Future<Result<void>> declineBooking({
    required String bookingId,
    required String driverId,
    required DriverDeclineReason reason,
    String? notes,
  }) async {
    try {
      await _client.post<Map<String, dynamic>>(
        '${AppConstants.apiV1Prefix}/bookings/$bookingId/decline',
        data: {'reason': reason.code, 'notes': notes},
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
          'fleet': fleet,
          'idempotencyKey': request.idempotencyKey,
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

  GroupBooking _groupFromServer(Map<String, dynamic> group) {
    final assignmentsRaw =
        (group['assignments'] as List? ?? const []).whereType<Map<String, dynamic>>();
    final assignments = assignmentsRaw.map((a) {
      final vehicle = (a['vehicle'] as Map<String, dynamic>?) ?? const {};
      final chauffeur = (a['chauffeur'] as Map<String, dynamic>?) ?? const {};
      return VehicleAssignment(
        assignmentId: (a['id'] as String?) ?? '',
        parentBookingId: (group['id'] as String?) ?? '',
        vehicleId: (vehicle['id'] as String?) ?? '',
        vehicleName:
            '${vehicle['display_name'] ?? ''} ${vehicle['fleet_code'] ?? ''}'.trim(),
        vehicleModel:
            (a['requested_model'] as String?) ?? (vehicle['display_name'] as String?) ?? '',
        capacity: 0,
        ownerName: (vehicle['registration_number'] as String?) ?? '',
        chauffeurId: (chauffeur['id'] as String?),
        chauffeurName: (chauffeur['full_name'] as String?),
        pricePaise: parseIntAmount(a['estimated_total_paise']),
        status: (a['status'] as String?) ?? 'PENDING',
      );
    }).toList();

    // Reconstruct fleet intent from the assignments' requested models.
    final units = <String, int>{};
    for (final a in assignments) {
      units[a.vehicleModel] = (units[a.vehicleModel] ?? 0) + 1;
    }

    return GroupBooking(
      parentBookingId: (group['id'] as String?) ?? '',
      bookingReference: (group['referenceCode'] as String?) ?? '',
      status: _statusFromWire(group['status'] as String?),
      customerIntent: CustomerFleetIntent.mixed(
        passengerCount: (group['passengerCount'] as num?)?.toInt() ?? 0,
        units: units,
      ),
      totalPassengers: (group['passengerCount'] as num?)?.toInt() ?? 0,
      totalVehicles: assignments.length,
      assignments: assignments,
      ceremonyType: (group['ceremonyType'] as String?) ?? '',
      serviceStartDateTime: parseDateTime(group['serviceStartTime']),
      serviceEndDateTime: parseDateTime(group['serviceEndTime']),
      city: (group['city'] as String?) ?? '',
      pickupAddress: (group['pickupAddress'] as String?) ?? '',
      destinationAddress: (group['destinationAddress'] as String?) ?? '',
      primaryContactName: (group['primaryContactName'] as String?) ?? '',
      primaryContactPhone: (group['primaryContactPhone'] as String?) ?? '',
      estimatedTotalPaise: parseIntAmount(group['estimatedTotalPaise']),
      advanceTokenPaise: parseIntAmount(group['advanceTokenPaise']),
      createdAt: parseDateTime(group['createdAt']),
    );
  }

  // ------------------------------------------------------------------
  // Shared row mappers
  // ------------------------------------------------------------------

  BookingStatus _statusFromWire(String? wire) => switch ((wire ?? '').toUpperCase()) {
    'DRAFT' => BookingStatus.requested,
    'REQUESTED' => BookingStatus.requested,
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

  BookingSummary _summaryFromRow(Map<String, dynamic> b) => BookingSummary(
        id: (b['id'] as String?) ?? '',
        reference: (b['referenceCode'] as String?) ?? '',
        serviceCategory:
            ((b['serviceCategory'] as Map<String, dynamic>?)?['title'] as String?) ??
                (b['serviceCategoryId'] as String?) ??
                '',
        status: parseBookingStatusWire(b['status'] as String?),
        eventStartTime: parseDateTime(b['serviceStartTime']),
        eventEndTime: parseDateTime(b['serviceEndTime']),
        pickupAddress: (b['pickupAddress'] as String?) ?? '',
        destinationAddress: (b['destinationAddress'] as String?) ?? '',
        routeDistanceKm: _doubleFromDecimal(b['routeDistanceKm']),
        vehicleName: (b['vehicleId'] as String?) ?? '',
        chauffeurName:
            ((b['driver'] as Map<String, dynamic>?)?['user']
                    as Map<String, dynamic>?)?['fullName'] as String? ??
                '',
        totalAmountCents: parseIntAmount(b['estimatedTotalPaise']),
        advanceTokenCents: parseIntAmount(b['advanceTokenPaise']),
        version: (b['version'] as num?)?.toInt() ?? 1,
      );

  BookingSubmissionResult _resultFromRow(Map<String, dynamic> b) {
    final driverUser =
        ((b['driver'] as Map<String, dynamic>?)?['user'] as Map<String, dynamic>?);
    return BookingSubmissionResult(
      bookingId: (b['id'] as String?) ?? '',
      bookingReference: (b['referenceCode'] as String?) ?? '',
      status: _statusFromWire(b['status'] as String?),
      submittedAt: parseDateTime(b['submittedAt']),
      vehicleId: (b['vehicleId'] as String?) ?? '',
      vehicleName: (b['vehicleId'] as String?) ?? '',
      vehicleClass: (b['vehicleTypeId'] as String?) ?? '',
      chauffeurId: (b['driverFk'] as String?) ?? '',
      ceremonyType: (b['ceremonyType'] as String?) ?? '',
      ceremonialAttire: (b['ceremonialAttire'] as String?) ?? '',
      serviceStartDateTime: parseDateTime(b['serviceStartTime']),
      serviceEndDateTime: parseDateTime(b['serviceEndTime']),
      routeDistanceKm: _doubleFromDecimal(b['routeDistanceKm']),
      pickupAddress: (b['pickupAddress'] as String?) ?? '',
      destinationAddress: (b['destinationAddress'] as String?) ?? '',
      primaryContactName:
          ((b['customer'] as Map<String, dynamic>?)?['fullName'] as String?) ??
              (b['primaryContactName'] as String?) ??
              '',
      primaryContactPhone:
          ((b['customer'] as Map<String, dynamic>?)?['phoneNumber'] as String?) ??
              (b['primaryContactPhone'] as String?) ??
              '',
      estimatedTotalPaise: parseIntAmount(b['estimatedTotalPaise']),
      advanceTokenPaise: parseIntAmount(b['advanceTokenPaise']),
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
