import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/core/result/result.dart';
import 'package:shadidriver/features/auth/domain/entities/auth_session.dart';
import 'package:shadidriver/features/auth/domain/entities/user_role.dart';
import 'package:shadidriver/features/auth/domain/entities/account_status.dart';
import 'package:shadidriver/features/auth/domain/repositories/auth_repository.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_draft.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_status.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_submission_request.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_submission_result.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_summary.dart';
import 'package:shadidriver/features/bookings/domain/repositories/booking_repository.dart';
import 'package:shadidriver/features/bookings/domain/entities/customer_fleet_intent.dart';
import 'package:shadidriver/features/bookings/domain/entities/fleet_availability_result.dart';
import 'package:shadidriver/features/bookings/domain/entities/group_booking.dart';
import 'package:shadidriver/features/bookings/domain/entities/group_booking_submission_request.dart';
import 'package:shadidriver/features/drivers/domain/entities/driver_decline_reason.dart';
import 'package:shadidriver/core/errors/failures.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Future<Result<String>> requestOtp({
    required String phoneNumber,
    UserRole? role,
  }) async {
    return const Result.success('session_test_999');
  }

  @override
  Future<Result<AuthSession>> verifyOtp({
    required String otpSessionId,
    required String otpCode,
  }) async {
    return Result.success(
      AuthSession(
        userId: 'usr_1',
        phone: '+91 99999 XXXXX',
        role: UserRole.customer,
        accountStatus: AccountStatus.active,
        issuedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<Result<String>> signUp({
    required String phoneNumber,
    required String displayName,
    UserRole role = UserRole.customer,
  }) async {
    return const Result.success('session_test_999');
  }

  @override
  Future<Result<AuthSession?>> restoreSession() async {
    return Result.success(
      AuthSession(
        userId: 'usr_1',
        phone: '+91 99999 XXXXX',
        role: UserRole.customer,
        accountStatus: AccountStatus.active,
        issuedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<Result<void>> signOut() async => const Result.success(null);

  @override
  Future<Result<AuthSession>> refreshSession() async {
    return Result.success(
      AuthSession(
        userId: 'usr_1',
        phone: '+91 99999 XXXXX',
        role: UserRole.customer,
        accountStatus: AccountStatus.active,
        issuedAt: DateTime.now(),
      ),
    );
  }
}

class FakeBookingRepository implements BookingRepository {
  final Map<String, BookingDraft> _drafts = {};

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

  @override
  Future<Result<BookingSummary>> getBookingById(String bookingId) async {
    return Result.success(
      BookingSummary(
        id: bookingId,
        reference: 'SHD-2026-TEST',
        serviceCategory: 'SVC_BARAAT',
        status: 'CONFIRMED',
        eventStartTime: DateTime(2026, 11, 20, 16),
        eventEndTime: DateTime(2026, 11, 20, 21),
        pickupAddress: 'Oberoi Grand, New Delhi',
        totalAmountCents: 1888000,
        advanceTokenCents: 377600,
        version: 1,
      ),
    );
  }

  @override
  Future<Result<List<BookingSummary>>> getMyBookings({
    int page = 1,
    int limit = 20,
    String? statusFilter,
  }) async => const Result.success([]);

  @override
  Future<Result<BookingSummary>> transitionState({
    required String bookingId,
    required String action,
    required int currentVersion,
    Map<String, dynamic>? metadata,
  }) async {
    return Result.success(
      BookingSummary(
        id: bookingId,
        reference: 'SHD-2026-TEST',
        serviceCategory: 'SVC_BARAAT',
        status: 'DRIVER_ARRIVING',
        eventStartTime: DateTime(2026, 11, 20, 16),
        eventEndTime: DateTime(2026, 11, 20, 21),
        pickupAddress: 'Oberoi Grand, New Delhi',
        totalAmountCents: 1888000,
        advanceTokenCents: 377600,
        version: currentVersion + 1,
      ),
    );
  }

  @override
  Future<Result<void>> cancelBooking({
    required String bookingId,
    required String reason,
  }) async => const Result.success(null);

  final Map<String, BookingSubmissionResult> _submissions = {};

  @override
  Future<Result<BookingSubmissionResult>> submitBooking(
    BookingSubmissionRequest request,
  ) async {
    final res = BookingSubmissionResult(
      bookingId: 'bk_test_1',
      bookingReference: 'SD-2026-0001',
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
      nextStepMessage: 'Test submission received.',
      isIdempotentReplay: false,
    );
    _submissions[res.bookingId] = res;
    return Result.success(res);
  }

  @override
  Future<Result<BookingSubmissionResult?>> getSubmissionResult(
    String bookingId,
  ) async {
    return Result.success(_submissions[bookingId]);
  }

  @override
  Future<Result<List<BookingSubmissionResult>>> getDriverBookingRequests({
    required String driverId,
  }) async {
    return Result.success(_submissions.values.toList());
  }

  @override
  Future<Result<List<BookingSubmissionResult>>> getDriverActiveAssignments({
    required String driverId,
  }) async {
    return Result.success(
      _submissions.values
          .where((s) => s.chauffeurId == driverId)
          .toList(),
    );
  }

  @override
  Future<Result<List<BookingSubmissionResult>>> getDispatchMonitorBookings() async {
    return Result.success(_submissions.values.toList());
  }

  @override
  Future<Result<List<BookingSubmissionResult>>> getCompletedBookings({
    required String driverId,
  }) async {
    return Result.success(
      _submissions.values
          .where((s) => s.status == BookingStatus.completed)
          .toList(),
    );
  }

  @override
  Future<Result<BookingSubmissionResult>> getDriverBookingDetails({
    required String bookingId,
    required String driverId,
  }) async {
    final s = _submissions[bookingId];
    if (s != null) return Result.success(s);
    return Result.failure(const NotFoundFailure('Not found'));
  }

  @override
  Future<Result<BookingSubmissionResult>> acceptBooking({
    required String bookingId,
    required String driverId,
  }) async {
    final s = _submissions[bookingId];
    if (s != null) {
      final accepted = BookingSubmissionResult(
        bookingId: s.bookingId,
        bookingReference: s.bookingReference,
        status: BookingStatus.driverAccepted,
        submittedAt: s.submittedAt,
        vehicleId: s.vehicleId,
        vehicleName: s.vehicleName,
        vehicleClass: s.vehicleClass,
        chauffeurId: driverId,
        ceremonyType: s.ceremonyType,
        ceremonialAttire: s.ceremonialAttire,
        serviceStartDateTime: s.serviceStartDateTime,
        serviceEndDateTime: s.serviceEndDateTime,
        routeDistanceKm: s.routeDistanceKm,
        pickupAddress: s.pickupAddress,
        destinationAddress: s.destinationAddress,
        primaryContactName: s.primaryContactName,
        primaryContactPhone: s.primaryContactPhone,
        estimatedTotalPaise: s.estimatedTotalPaise,
        advanceTokenPaise: s.advanceTokenPaise,
        advanceTokenLabel: s.advanceTokenLabel,
        nextStepMessage: 'Driver accepted',
      );
      _submissions[bookingId] = accepted;
      return Result.success(accepted);
    }
    return Result.failure(const NotFoundFailure('Not found'));
  }

  @override
  Future<Result<void>> declineBooking({
    required String bookingId,
    required String driverId,
    required DriverDeclineReason reason,
    String? notes,
  }) async {
    return const Result.success(null);
  }

  @override
  Future<Result<FleetAvailabilityResult>> checkFleetAvailability(
    CustomerFleetIntent intent,
  ) async {
    return Result.success(
      FleetAvailabilityResult.available(
        model: intent.preferredModel,
        count: intent.totalRequestedUnits,
      ),
    );
  }

  @override
  Future<Result<GroupBooking>> submitGroupBooking(
    GroupBookingSubmissionRequest request,
  ) async {
    return Result.success(
      GroupBooking(
        parentBookingId: 'grp_test_1',
        bookingReference: 'SD-GRP-2026-0001',
        status: BookingStatus.requested,
        customerIntent: request.fleetIntent,
        totalPassengers: request.fleetIntent.passengerCount,
        totalVehicles: 1,
        assignments: const [],
        ceremonyType: request.ceremonyType,
        serviceStartDateTime: request.serviceStartDateTime,
        serviceEndDateTime: request.serviceEndDateTime,
        city: request.city,
        pickupAddress: request.pickupAddress,
        destinationAddress: request.destinationAddress,
        primaryContactName: request.primaryContactName,
        primaryContactPhone: request.primaryContactPhone,
        estimatedTotalPaise: 5000000,
        advanceTokenPaise: 1000000,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<Result<GroupBooking?>> getGroupBooking(String parentBookingId) async {
    return const Result.success(null);
  }
}

void main() {
  group('Domain Repository Contracts Verification', () {
    test(
      'FakeAuthRepository implements contract and yields typed results',
      () async {
        final repo = FakeAuthRepository();
        final otpRes = await repo.requestOtp(
          phoneNumber: '+919876543210',
          role: UserRole.customer,
        );

        expect(otpRes.isSuccess, isTrue);
        expect(otpRes.dataOrNull, equals('session_test_999'));

        final verifyRes = await repo.verifyOtp(
          otpSessionId: 'session_test_999',
          otpCode: '123456',
        );

        expect(verifyRes.isSuccess, isTrue);
        expect(verifyRes.dataOrNull?.role, equals(UserRole.customer));
      },
    );

    test('FakeBookingRepository transitions state atomically', () async {
      final repo = FakeBookingRepository();
      final transRes = await repo.transitionState(
        bookingId: 'b_123',
        action: 'START_EN_ROUTE',
        currentVersion: 1,
      );

      expect(transRes.isSuccess, isTrue);
      expect(transRes.dataOrNull?.status, equals('DRIVER_ARRIVING'));
      expect(transRes.dataOrNull?.version, equals(2));
    });

    test('FakeBookingRepository creates and retrieves booking draft', () async {
      final repo = FakeBookingRepository();
      final initialDraft = BookingDraft.initial(
        vehicleId: 'v_test',
        vehicleName: 'Mercedes-Benz E-Class',
        vehicleClass: 'Luxury Sedan',
        chauffeurId: 'd_test',
        basePricePaise: 3000000,
        estimatedTotalPaise: 3000000,
        advanceTokenPaise: 600000,
      );

      final createRes = await repo.createBookingDraft(initialDraft);
      expect(createRes.isSuccess, isTrue);
      expect(createRes.dataOrNull?.vehicleId, equals('v_test'));

      final getRes = await repo.getBookingDraft(initialDraft.id);
      expect(getRes.isSuccess, isTrue);
      expect(getRes.dataOrNull?.vehicleName, equals('Mercedes-Benz E-Class'));
    });

    test(
      'FakeBookingRepository submits booking intent and returns submission result',
      () async {
        final repo = FakeBookingRepository();
        final draft =
            BookingDraft.initial(
              vehicleId: 'v_test',
              vehicleName: 'Mercedes-Benz E-Class',
              vehicleClass: 'Luxury Sedan',
              chauffeurId: 'd_test',
              basePricePaise: 3000000,
              estimatedTotalPaise: 3000000,
              advanceTokenPaise: 600000,
            ).copyWith(
              pickupAddress: 'The Oberoi, New Delhi',
              destinationAddress: 'Grand Imperial Banquets',
              primaryContactName: 'Vikram Malhotra',
              primaryContactPhone: '9810012345',
            );

        final request = BookingSubmissionRequest.fromDraft(
          draft,
          idempotencyKey: 'idem_test_key_001',
        );

        final submitRes = await repo.submitBooking(request);
        expect(submitRes.isSuccess, isTrue);
        expect(submitRes.dataOrNull?.bookingId, equals('bk_test_1'));
        expect(submitRes.dataOrNull?.bookingReference, equals('SD-2026-0001'));
        expect(submitRes.dataOrNull?.status, equals(BookingStatus.requested));

        final resultRes = await repo.getSubmissionResult('bk_test_1');
        expect(resultRes.isSuccess, isTrue);
        expect(resultRes.dataOrNull?.bookingReference, equals('SD-2026-0001'));
      },
    );

    test(
      'FakeBookingRepository accepts and declines driver booking request',
      () async {
        final repo = FakeBookingRepository();
        final draft =
            BookingDraft.initial(
              vehicleId: 'v_test',
              vehicleName: 'Mercedes-Benz E-Class',
              vehicleClass: 'Luxury Sedan',
              chauffeurId: 'd_test',
              basePricePaise: 3000000,
              estimatedTotalPaise: 3000000,
              advanceTokenPaise: 600000,
            ).copyWith(
              pickupAddress: 'The Oberoi, New Delhi',
              destinationAddress: 'Grand Imperial Banquets',
              primaryContactName: 'Vikram Malhotra',
              primaryContactPhone: '9810012345',
            );

        final request = BookingSubmissionRequest.fromDraft(
          draft,
          idempotencyKey: 'idem_test_key_002',
        );

        await repo.submitBooking(request);

        final requestsRes = await repo.getDriverBookingRequests(driverId: 'd1');
        expect(requestsRes.isSuccess, isTrue);
        expect(requestsRes.dataOrNull?.length, equals(1));

        final acceptRes = await repo.acceptBooking(
          bookingId: 'bk_test_1',
          driverId: 'd1',
        );
        expect(acceptRes.isSuccess, isTrue);
        expect(
          acceptRes.dataOrNull?.status,
          equals(BookingStatus.driverAccepted),
        );

        final declineRes = await repo.declineBooking(
          bookingId: 'bk_test_1',
          driverId: 'd1',
          reason: DriverDeclineReason.timingConflict,
        );
        expect(declineRes.isSuccess, isTrue);
      },
    );
  });
}
