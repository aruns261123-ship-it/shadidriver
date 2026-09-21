import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/shadi_empty_state.dart';
import '../../../core/widgets/shadi_loading_indicator.dart';
import '../../../core/widgets/shadi_primary_button.dart';
import '../../../core/utils/date_formatter.dart';
import '../../notifications/presentation/controllers/notifications_controller.dart';
import 'controllers/customer_messages_controller.dart';

/// Customer Messages tab: conversation threads derived from the live
/// notification feed (booking updates, chauffeur assignments, payments,
/// support replies). Replaces the former placeholder screen.
class CustomerMessagesScreen extends ConsumerWidget {
  const CustomerMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threads = ref.watch(customerMessagesProvider);
    final notificationsAsync =
        ref.watch(notificationsControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Messages',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.primaryBurgundy,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: notificationsAsync.isLoading && threads.isEmpty
          ? const Center(child: ShadiLoadingIndicator())
          : RefreshIndicator(
              color: AppColors.primaryBurgundy,
              onRefresh: () async {
                await ref
                    .read(notificationsControllerProvider.notifier)
                    .refresh();
              },
              child: threads.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.only(top: 120),
                          child: ShadiEmptyState(
                            icon: Icons.chat_bubble_outline_rounded,
                            title: 'No Messages Yet',
                            description:
                                'Booking updates, chauffeur assignments, and support replies will appear here as conversations.',
                          ),
                        ),
                        SizedBox(height: 24),
                        _SupportCta(),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: threads.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final thread = threads[index];
                        return _MessageThreadCard(thread: thread);
                      },
                    ),
            ),
    );
  }
}

class _MessageThreadCard extends StatelessWidget {
  final MessageThread thread;

  const _MessageThreadCard({required this.thread});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: thread.isUnread
              ? AppColors.primaryBurgundy.withValues(alpha: 0.25)
              : AppColors.champagneGold,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: thread.isUnread
              ? AppColors.primaryBurgundy.withValues(alpha: 0.1)
              : AppColors.champagneGold.withValues(alpha: 0.3),
          child: Icon(
            thread.isUnread
                ? Icons.mark_email_unread_rounded
                : Icons.forum_outlined,
            color: AppColors.primaryBurgundy,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                thread.title,
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.primaryBurgundy,
                  fontWeight: thread.isUnread
                      ? FontWeight.w700
                      : FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              DateFormatter.formatCeremonyTime(thread.lastActivityAt),
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            thread.lastMessage,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondaryLight,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _SupportCta extends ConsumerWidget {
  const _SupportCta();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: ShadiPrimaryButton(
        text: 'Contact Royal Concierge',
        onPressed: () => context.push(RoutePaths.customerSupportTicket),
      ),
    );
  }
}
