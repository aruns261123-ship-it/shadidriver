import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers/app_providers.dart';
import '../../domain/entities/admin_profile.dart';
import '../../domain/repositories/admin_profile_repository.dart';
import '../../domain/services/profile_photo_service.dart';

class AdminProfileState {
  final AdminProfile? profile;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final String? successMessage;

  const AdminProfileState({
    this.profile,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.successMessage,
  });

  AdminProfileState copyWith({
    AdminProfile? profile,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return AdminProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages
          ? null
          : (successMessage ?? this.successMessage),
    );
  }
}

class AdminProfileController extends StateNotifier<AdminProfileState> {
  final AdminProfileRepository repository;
  final ProfilePhotoService photoService;
  final String adminId;

  AdminProfileController({
    required this.repository,
    required this.photoService,
    required this.adminId,
  }) : super(const AdminProfileState(isLoading: true)) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    final res = await repository.getProfile(adminId);
    res.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
      (profile) => state = state.copyWith(isLoading: false, profile: profile),
    );
  }

  Future<bool> updateContactInfo({
    required String fullName,
    required String phone,
  }) async {
    state = state.copyWith(isSaving: true, clearMessages: true);
    final res = await repository.updateContactInfo(
      adminId: adminId,
      fullName: fullName,
      phone: phone,
    );
    return res.fold(
      (failure) {
        state = state.copyWith(isSaving: false, errorMessage: failure.message);
        return false;
      },
      (saved) {
        state = state.copyWith(
          isSaving: false,
          profile: saved,
          successMessage: 'Admin contact details updated.',
        );
        return true;
      },
    );
  }

  Future<bool> pickAndSavePhotoFromGallery() async {
    state = state.copyWith(isSaving: true, clearMessages: true);
    final pickRes = await photoService.pickFromGallery();
    return pickRes.fold(
      (failure) {
        state = state.copyWith(isSaving: false, errorMessage: failure.message);
        return false;
      },
      (photoRef) async {
        final saveRes = await photoService.savePhoto(
          userId: adminId,
          imageRef: photoRef,
        );
        return saveRes.fold(
          (failure) {
            state = state.copyWith(
              isSaving: false,
              errorMessage: failure.message,
            );
            return false;
          },
          (canonicalUrl) async {
            final repoRes = await repository.updateProfilePhoto(
              adminId: adminId,
              photoUrl: canonicalUrl,
            );
            return repoRes.fold(
              (failure) {
                state = state.copyWith(
                  isSaving: false,
                  errorMessage: failure.message,
                );
                return false;
              },
              (url) {
                if (state.profile != null) {
                  state = state.copyWith(
                    isSaving: false,
                    profile: state.profile!.copyWithContactInfo(photoUrl: url),
                    successMessage: 'Admin profile photo updated.',
                  );
                }
                return true;
              },
            );
          },
        );
      },
    );
  }
}

final adminProfileControllerProvider =
    StateNotifierProvider.family<
      AdminProfileController,
      AdminProfileState,
      String
    >((ref, adminId) {
      final repo = ref.watch(adminProfileRepositoryProvider);
      final photoService = ref.watch(profilePhotoServiceProvider);
      return AdminProfileController(
        repository: repo,
        photoService: photoService,
        adminId: adminId,
      );
    });
