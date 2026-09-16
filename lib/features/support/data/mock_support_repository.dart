import '../../../../core/result/result.dart';
import '../domain/repositories/support_repository.dart';

/// In-memory mock implementation of SupportRepository.
class MockSupportRepository implements SupportRepository {
  final List<Map<String, dynamic>> _tickets = [];

  @override
  Future<Result<String>> createSupportTicket({
    required String bookingId,
    required String category,
    required String message,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final ticketId = 'TKT-${DateTime.now().millisecondsSinceEpoch % 100000}';
    _tickets.add({
      'ticketId': ticketId,
      'bookingId': bookingId,
      'category': category,
      'message': message,
      'createdAt': DateTime.now(),
    });
    return Result.success(ticketId);
  }
}
