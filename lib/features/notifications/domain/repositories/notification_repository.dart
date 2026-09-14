import '../../../../core/result/result.dart';
import '../entities/notification_item.dart';

/// Pure Dart domain contract for notifications.
abstract interface class NotificationRepository {
  Future<Result<List<NotificationItem>>> getNotifications({
    int page = 1,
    int limit = 20,
  });
  Future<Result<void>> markAsRead(String notificationId);
}
