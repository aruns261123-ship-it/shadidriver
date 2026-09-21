import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadidriver/app/providers/app_providers.dart';

import '../../domain/entities/notification_item.dart';

/// Loads in-app notifications and mirrors read-state mutations locally.
class NotificationsController extends AsyncNotifier<List<NotificationItem>> {
  @override
  Future<List<NotificationItem>> build() async {
    final repo = ref.read(notificationRepositoryProvider);
    final result = await repo.getNotifications();
    return result.dataOrNull ?? const <NotificationItem>[];
  }

  Future<void> refresh() async {
    state = const AsyncLoading<List<NotificationItem>>().copyWithPrevious(
      state,
      isRefresh: true,
    );
    final repo = ref.read(notificationRepositoryProvider);
    final result = await repo.getNotifications();
    state = AsyncData(result.dataOrNull ?? const <NotificationItem>[]);
  }

  /// Marks a notification as read at the source and updates local state.
  Future<void> markAsRead(String notificationId) async {
    final repo = ref.read(notificationRepositoryProvider);
    await repo.markAsRead(notificationId);
    final current = state.valueOrNull ?? const <NotificationItem>[];
    state = AsyncData([
      for (final notification in current)
        if (notification.id == notificationId)
          NotificationItem(
            id: notification.id,
            title: notification.title,
            body: notification.body,
            isRead: true,
            createdAt: notification.createdAt,
          )
        else
          notification,
    ]);
  }
}

final notificationsControllerProvider =
    AsyncNotifierProvider<NotificationsController, List<NotificationItem>>(
      NotificationsController.new,
    );

/// Number of unread notifications; drives the home-screen bell badge.
final unreadNotificationsCountProvider = Provider<int>((ref) {
  return ref
          .watch(notificationsControllerProvider)
          .valueOrNull
          ?.where((notification) => !notification.isRead)
          .length ??
      0;
});
