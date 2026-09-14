import '../../../../core/result/result.dart';
import '../entities/booking_summary.dart';

/// Pure Dart domain contract for booking lifecycle operations.
abstract interface class BookingRepository {
  Future<Result<BookingSummary>> getBookingById(String bookingId);

  Future<Result<List<BookingSummary>>> getMyBookings({
    int page = 1,
    int limit = 20,
    String? statusFilter,
  });

  Future<Result<BookingSummary>> transitionState({
    required String bookingId,
    required String action,
    required int currentVersion,
    Map<String, dynamic>? metadata,
  });

  Future<Result<void>> cancelBooking({
    required String bookingId,
    required String reason,
  });
}
