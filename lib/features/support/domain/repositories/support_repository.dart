import '../../../../core/result/result.dart';

/// Pure Dart domain contract for dispute mediation and support tickets.
abstract interface class SupportRepository {
  Future<Result<String>> createSupportTicket({
    required String bookingId,
    required String category,
    required String message,
  });
}
