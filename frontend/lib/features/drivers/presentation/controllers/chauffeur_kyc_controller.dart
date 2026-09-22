import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers/app_providers.dart';
import '../../domain/entities/chauffeur_kyc_application.dart';
import '../../domain/repositories/chauffeur_kyc_repository.dart';

/// State for the admin Chauffeur KYC verification queue.
@immutable
class ChauffeurKycState {
  final List<ChauffeurKycApplication> applications;
  final bool isLoading;
  final String? errorMessage;

  /// Application ID currently being adjudicated (drives button spinners).
  final String? actingApplicationId;

  const ChauffeurKycState({
    this.applications = const [],
    this.isLoading = false,
    this.errorMessage,
    this.actingApplicationId,
  });

  int get pendingCount =>
      applications.where((a) => a.status == ChauffeurKycStatus.pending).length;

  ChauffeurKycState copyWith({
    List<ChauffeurKycApplication>? applications,
    bool? isLoading,
    String? errorMessage,
    String? actingApplicationId,
    bool clearError = false,
    bool clearActing = false,
  }) {
    return ChauffeurKycState(
      applications: applications ?? this.applications,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      actingApplicationId: clearActing
          ? null
          : (actingApplicationId ?? this.actingApplicationId),
    );
  }
}

/// Controller for the admin Chauffeur KYC & Verification queue.
///
/// Backed by [ChauffeurKycRepository]; approval/rejection flips the real
/// chauffeur profile's verification status through the shared driver store.
class ChauffeurKycController extends StateNotifier<ChauffeurKycState> {
  final ChauffeurKycRepository repository;

  ChauffeurKycController({required this.repository})
    : super(const ChauffeurKycState(isLoading: true)) {
    loadApplications();
  }

  Future<void> loadApplications() async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await repository.getApplications();
    if (!mounted) return;

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
      (applications) =>
          state = state.copyWith(isLoading: false, applications: applications),
    );
  }

  /// Approves a pending application. Returns true on success.
  Future<bool> approve(String applicationId) async {
    if (state.actingApplicationId != null) return false;
    state = state.copyWith(
      actingApplicationId: applicationId,
      clearError: true,
    );

    final result = await repository.approveApplication(applicationId);
    if (!mounted) return false;

    return result.fold(
      (failure) {
        state = state.copyWith(
          actingApplicationId: null,
          errorMessage: failure.message,
        );
        return false;
      },
      (updated) {
        state = state.copyWith(
          actingApplicationId: null,
          applications: _replaceApplication(updated),
        );
        return true;
      },
    );
  }

  /// Rejects a pending application with a mandatory reason. Returns true on
  /// success.
  Future<bool> reject(String applicationId, {required String reason}) async {
    if (state.actingApplicationId != null) return false;
    state = state.copyWith(
      actingApplicationId: applicationId,
      clearError: true,
    );

    final result = await repository.rejectApplication(
      applicationId,
      reason: reason,
    );
    if (!mounted) return false;

    return result.fold(
      (failure) {
        state = state.copyWith(
          actingApplicationId: null,
          errorMessage: failure.message,
        );
        return false;
      },
      (updated) {
        state = state.copyWith(
          actingApplicationId: null,
          applications: _replaceApplication(updated),
        );
        return true;
      },
    );
  }

  /// Attaches an uploaded document to a pending application (driver-side
  /// submission path shared by the admin viewer). Returns true on success.
  Future<bool> uploadDocument({
    required String applicationId,
    required KycDocumentType documentType,
    required String fileReference,
  }) async {
    state = state.copyWith(
      actingApplicationId: applicationId,
      clearError: true,
    );

    final result = await repository.uploadDocument(
      applicationId: applicationId,
      documentType: documentType,
      fileReference: fileReference,
    );
    if (!mounted) return false;

    return result.fold(
      (failure) {
        state = state.copyWith(
          actingApplicationId: null,
          errorMessage: failure.message,
        );
        return false;
      },
      (updated) {
        state = state.copyWith(
          actingApplicationId: null,
          applications: _replaceApplication(updated),
        );
        return true;
      },
    );
  }

  List<ChauffeurKycApplication> _replaceApplication(
    ChauffeurKycApplication updated,
  ) {
    return state.applications
        .map((a) => a.applicationId == updated.applicationId ? updated : a)
        .toList();
  }
}

/// Provider for the admin KYC verification queue.
final chauffeurKycControllerProvider =
    StateNotifierProvider.autoDispose<
      ChauffeurKycController,
      ChauffeurKycState
    >((ref) {
      return ChauffeurKycController(
        repository: ref.watch(chauffeurKycRepositoryProvider),
      );
    });
