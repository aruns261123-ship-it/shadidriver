import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/shadi_primary_button.dart';
import 'controllers/support_ticket_controller.dart';

/// Customer help & dispute screen: raises a support ticket tied to a booking.
///
/// Reached from the Account Center concierge item; [bookingId] is optional so
/// general (non-booking) disputes can also be filed.
class SupportTicketScreen extends ConsumerStatefulWidget {
  final String? bookingId;

  const SupportTicketScreen({super.key, this.bookingId});

  @override
  ConsumerState<SupportTicketScreen> createState() =>
      _SupportTicketScreenState();
}

class _SupportTicketScreenState extends ConsumerState<SupportTicketScreen> {
  String _category = supportTicketCategories.first;
  final _messageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supportTicketControllerProvider);

    if (state.isSuccess) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'Support',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.primaryBurgundy,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBurgundy.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: AppColors.primaryBurgundy,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Ticket Raised',
                  style: AppTypography.titleLarge.copyWith(
                    color: AppColors.primaryBurgundy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Our wedding transport managers will respond within 2 hours.\nReference: ${state.ticketId}',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 32),
                ShadiPrimaryButton(
                  text: 'Done',
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Royal Concierge Support',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.primaryBurgundy,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.bookingId != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.champagneGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_rounded,
                      color: AppColors.primaryBurgundy,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dispute for booking ${widget.bookingId}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.primaryBurgundy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 1. Category
            Text(
              'Issue Category',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: supportTicketCategories
                  .map(
                    (c) => ChoiceChip(
                      label: Text(c),
                      selected: _category == c,
                      selectedColor: AppColors.primaryBurgundy.withValues(
                        alpha: 0.15,
                      ),
                      labelStyle: AppTypography.labelLarge.copyWith(
                        color: _category == c
                            ? AppColors.primaryBurgundy
                            : AppColors.textSecondaryLight,
                        fontWeight: _category == c
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      onSelected: (_) => setState(() => _category = c),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),

            // 2. Message
            Text(
              'Describe the Issue',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _messageController,
              maxLines: 5,
              minLines: 3,
              decoration: InputDecoration(
                hintText:
                    'Tell us what went wrong — include times, names, and any photos you can share later.',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              validator: (value) => (value == null || value.trim().length < 10)
                  ? 'Please describe the issue (at least 10 characters)'
                  : null,
            ),
            const SizedBox(height: 28),

            // 3. Submit
            ShadiPrimaryButton(
              key: const Key('submit_support_ticket_btn'),
              text: 'Raise Support Ticket',
              isLoading: state.isSubmitting,
              onPressed: state.isSubmitting
                  ? null
                  : () {
                      if (!_formKey.currentState!.validate()) return;
                      ref
                          .read(supportTicketControllerProvider.notifier)
                          .submitTicket(
                            bookingId: widget.bookingId ?? 'none',
                            category: _category,
                            message: _messageController.text.trim(),
                          );
                    },
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(color: Colors.red),
              ),
            ],
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.champagneGold),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.phone_in_talk_rounded,
                    color: AppColors.primaryBurgundy,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ceremony-day emergencies? Call the 24/7 helpline at +91 98100 00000 — calls take priority over tickets.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
