import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers/app_providers.dart';
import '../../../services/domain/entities/service_category.dart';
import '../../domain/repositories/urgent_dispatch_repository.dart';

/// State machine for the customer urgent-dispatch (SOS) request.
@immutable
class UrgentDispatchState {
  final bool isSubmitting;
  final String? dispatchId;
  final String? errorMessage;

  const UrgentDispatchState({
    this.isSubmitting = false,
    this.dispatchId,
    this.errorMessage,
  });

  bool get isSuccess => dispatchId != null;

  UrgentDispatchState copyWith({
    bool? isSubmitting,
    String? dispatchId,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UrgentDispatchState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      dispatchId: dispatchId ?? this.dispatchId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Submits an urgent chauffeur dispatch request on behalf of the customer.
///
/// Demo devices have no GPS permission wiring yet, so the pickup coordinates
/// use the service area centroid (Delhi NCR) with the customer-typed address.
class UrgentDispatchController extends StateNotifier<UrgentDispatchState> {
  final UrgentDispatchRepository repository;

  UrgentDispatchController({required this.repository})
    : super(const UrgentDispatchState());

  Future<void> submitRequest({
    required ServiceCategory category,
    required String address,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);

    // Delhi NCR service-area centroid — replaced by device GPS later.
    final result = await repository.requestUrgentChauffeur(
      serviceCategory: category.name,
      latitude: 28.6139,
      longitude: 77.2090,
      address: address,
    );

    if (!mounted) return;

    result.fold(
      (failure) => state = state.copyWith(
        isSubmitting: false,
        errorMessage: failure.message,
      ),
      (dispatchId) =>
          state = state.copyWith(isSubmitting: false, dispatchId: dispatchId),
    );
  }
}

/// Provider for the urgent dispatch SOS screen.
final urgentDispatchControllerProvider =
    StateNotifierProvider.autoDispose<
      UrgentDispatchController,
      UrgentDispatchState
    >((ref) {
      return UrgentDispatchController(
        repository: ref.watch(urgentDispatchRepositoryProvider),
      );
    });
