import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers/app_providers.dart';
import '../../../support/domain/repositories/support_repository.dart';

/// State for the customer support ticket submission.
@immutable
class SupportTicketState {
  final bool isSubmitting;
  final String? ticketId;
  final String? errorMessage;

  const SupportTicketState({
    this.isSubmitting = false,
    this.ticketId,
    this.errorMessage,
  });

  bool get isSuccess => ticketId != null;

  SupportTicketState copyWith({
    bool? isSubmitting,
    String? ticketId,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SupportTicketState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      ticketId: ticketId ?? this.ticketId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Submits customer support/dispute tickets through the repository.
class SupportTicketController extends StateNotifier<SupportTicketState> {
  final SupportRepository repository;

  SupportTicketController({required this.repository})
    : super(const SupportTicketState());

  Future<void> submitTicket({
    required String bookingId,
    required String category,
    required String message,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);

    final result = await repository.createSupportTicket(
      bookingId: bookingId,
      category: category,
      message: message,
    );

    if (!mounted) return;

    result.fold(
      (failure) => state = state.copyWith(
        isSubmitting: false,
        errorMessage: failure.message,
      ),
      (ticketId) =>
          state = state.copyWith(isSubmitting: false, ticketId: ticketId),
    );
  }

  /// Resets to a fresh form (used after the success card is dismissed).
  void reset() {
    state = const SupportTicketState();
  }
}

/// Categories offered on the support ticket form.
const supportTicketCategories = <String>[
  'Booking Dispute',
  'Chauffeur Conduct',
  'Vehicle Condition',
  'Billing & Refund',
  'Schedule Change',
  'Other',
];

/// Provider for the support ticket screen.
final supportTicketControllerProvider =
    StateNotifierProvider.autoDispose<
      SupportTicketController,
      SupportTicketState
    >((ref) {
      return SupportTicketController(
        repository: ref.watch(supportRepositoryProvider),
      );
    });
