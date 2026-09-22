import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../notifications/domain/entities/notification_item.dart';
import '../../../notifications/presentation/controllers/notifications_controller.dart';

/// One conversation thread on the customer Messages tab.
@immutable
class MessageThread {
  final String id;
  final String title;
  final String lastMessage;
  final DateTime lastActivityAt;
  final bool isUnread;

  const MessageThread({
    required this.id,
    required this.title,
    required this.lastMessage,
    required this.lastActivityAt,
    required this.isUnread,
  });
}

/// Derives the customer's message threads from the shared notification feed —
/// the same store booking lifecycle events, chauffeur assignments, and payment
/// confirmations are pushed to, so Messages stays live automatically.
final customerMessagesProvider = Provider<List<MessageThread>>((ref) {
  final items =
      ref.watch(notificationsControllerProvider).valueOrNull ??
      const <NotificationItem>[];

  return [
    for (final n in items)
      MessageThread(
        id: n.id,
        title: n.title,
        lastMessage: n.body,
        lastActivityAt: n.createdAt,
        isUnread: !n.isRead,
      ),
  ];
});
