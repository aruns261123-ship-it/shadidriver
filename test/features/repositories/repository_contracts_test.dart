import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/core/result/result.dart';
import 'package:shadidriver/features/auth/domain/entities/auth_session.dart';
import 'package:shadidriver/features/auth/domain/entities/user_role.dart';
import 'package:shadidriver/features/auth/domain/entities/account_status.dart';
import 'package:shadidriver/features/auth/domain/repositories/auth_repository.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_summary.dart';
import 'package:shadidriver/features/bookings/domain/repositories/booking_repository.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Future<Result<String>> requestOtp({
    required String phoneNumber,
    required UserRole role,
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
  });
}
