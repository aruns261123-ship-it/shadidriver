import '../../../../core/result/result.dart';
import '../domain/entities/notification_item.dart';
import '../domain/repositories/notification_repository.dart';

/// In-memory mock implementation of NotificationRepository with pre-seeded ceremonial alerts.
class MockNotificationRepository implements NotificationRepository {
  final List<NotificationItem> _notifications = [
    NotificationItem(
      id: 'notif_1',
      title: 'Booking Request Received',
      body:
          'Your Baraat ceremony reservation request SD-2026-0100 is under chauffeur review.',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
    ),
    NotificationItem(
      id: 'notif_2',
      title: 'Chauffeur Allocated',
      body:
          'Royal Chauffeur Rajesh Kumar (PB-01) has been assigned to your ceremony.',
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    NotificationItem(
      id: 'notif_3',
      title: 'Ceremonial Standards Confirmed',
      body: 'Chauffeur attire verified: Royal Bandhgala & Gold Safa.',
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  @override
  Future<Result<List<NotificationItem>>> getNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return Result.success(List.unmodifiable(_notifications));
  }

  @override
  Future<Result<void>> markAsRead(String notificationId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      final old = _notifications[index];
      _notifications[index] = NotificationItem(
        id: old.id,
        title: old.title,
        body: old.body,
        isRead: true,
        createdAt: old.createdAt,
      );
    }
    return const Result.success(null);
  }
}
