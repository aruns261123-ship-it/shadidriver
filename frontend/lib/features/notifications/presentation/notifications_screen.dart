import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/shadi_card.dart';
import '../../../../core/widgets/shadi_empty_state.dart';
import '../../../../core/widgets/shadi_error_view.dart';
import '../../../../core/widgets/shadi_loading_indicator.dart';
import '../domain/entities/notification_item.dart';
import 'controllers/notifications_controller.dart';

/// Customer notifications screen — ceremonial booking alerts and updates.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Notifications',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.primaryBurgundy,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: notificationsAsync.when(
        loading: () => const ShadiLoadingIndicator(
          message: 'Fetching your ceremonial updates...',
        ),
        error: (err, _) => ShadiErrorView(
          message: 'Could not load notifications. Please try again.',
          onRetry: () =>
              ref.read(notificationsControllerProvider.notifier).refresh(),
        ),
        data: (notifications) => RefreshIndicator(
          color: AppColors.primaryBurgundy,
          onRefresh: () =>
              ref.read(notificationsControllerProvider.notifier).refresh(),
          child: notifications.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: ShadiEmptyState(
                        icon: Icons.notifications_off_rounded,
                        title: 'All Quiet',
                        description:
                            'No ceremonial updates right now. Booking alerts will appear here.',
                        actionLabel: 'Refresh',
                        onAction: () => ref
                            .read(notificationsControllerProvider.notifier)
                            .refresh(),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) =>
                      _NotificationTile(item: notifications[index]),
                ),
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final NotificationItem item;

  const _NotificationTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ShadiCard(
        onTap: item.isRead
            ? null
            : () => ref
                  .read(notificationsControllerProvider.notifier)
                  .markAsRead(item.id),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.isRead
                    ? AppColors.secondarySurface
                    : AppColors.champagneGold.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                item.isRead
                    ? Icons.notifications_none_rounded
                    : Icons.notifications_active_rounded,
                color: item.isRead
                    ? AppColors.textTertiaryLight
                    : AppColors.primaryBurgundy,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: AppTypography.titleSmall.copyWith(
                            color: item.isRead
                                ? AppColors.textSecondaryLight
                                : AppColors.primaryBurgundy,
                            fontWeight: item.isRead
                                ? FontWeight.w600
                                : FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        _timeAgo(item.createdAt),
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textTertiaryLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondaryLight,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (!item.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: AppColors.champagneGold,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime createdAt) {
    final difference = DateTime.now().difference(createdAt);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}
