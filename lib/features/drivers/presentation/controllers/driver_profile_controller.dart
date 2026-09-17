import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers/app_providers.dart';
import '../../domain/entities/driver_profile.dart';
import '../../domain/repositories/driver_profile_repository.dart';
import '../../../profile/domain/services/profile_photo_service.dart';

class DriverProfileState {
  final DriverProfile? profile;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final String? successMessage;

  const DriverProfileState({
    this.profile,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.successMessage,
  });

  DriverProfileState copyWith({
    DriverProfile? profile,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return DriverProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }
}

class DriverProfileController extends StateNotifier<DriverProfileState> {
  final DriverProfileRepository repository;
  final ProfilePhotoService photoService;
  final String driverId;

  DriverProfileController({
    required this.repository,
    required this.photoService,
    required this.driverId,
  }) : super(const DriverProfileState(isLoading: true)) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    final res = await repository.getProfile(driverId);
    res.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
      (profile) => state = state.copyWith(isLoading: false, profile: profile),
    );
  }

  Future<bool> updateProfile(DriverProfile updated) async {
    state = state.copyWith(isSaving: true, clearMessages: true);
    final res = await repository.updateProfile(updated);
    return res.fold(
      (failure) {
        state = state.copyWith(isSaving: false, errorMessage: failure.message);
        return false;
      },
      (saved) {
        state = state.copyWith(
          isSaving: false,
          profile: saved,
          successMessage: 'Chauffeur profile updated successfully.',
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
          userId: driverId,
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
              driverId: driverId,
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
                    profile: state.profile!.copyWith(profileImageUrl: url),
                    successMessage: 'Chauffeur photo updated.',
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

  Future<bool> captureAndSavePhotoFromCamera() async {
    state = state.copyWith(isSaving: true, clearMessages: true);
    final capRes = await photoService.captureFromCamera();
    return capRes.fold(
      (failure) {
        state = state.copyWith(isSaving: false, errorMessage: failure.message);
        return false;
      },
      (photoRef) async {
        final saveRes = await photoService.savePhoto(
          userId: driverId,
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
              driverId: driverId,
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
                    profile: state.profile!.copyWith(profileImageUrl: url),
                    successMessage: 'Chauffeur photo captured and updated.',
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

  Future<bool> removePhoto() async {
    state = state.copyWith(isSaving: true, clearMessages: true);
    await photoService.removePhoto(driverId);
    if (state.profile != null) {
      final updated = state.profile!.copyWith(clearProfileImage: true);
      final res = await repository.updateProfile(updated);
      return res.fold(
        (failure) {
          state = state.copyWith(
            isSaving: false,
            errorMessage: failure.message,
          );
          return false;
        },
        (saved) {
          state = state.copyWith(
            isSaving: false,
            profile: saved,
            successMessage: 'Chauffeur photo removed.',
          );
          return true;
        },
      );
    }
    state = state.copyWith(isSaving: false);
    return true;
  }
}

final driverProfileControllerProvider = StateNotifierProvider.family<
    DriverProfileController, DriverProfileState, String>((ref, driverId) {
  final repo = ref.watch(driverProfileRepositoryProvider);
  final photoService = ref.watch(profilePhotoServiceProvider);
  return DriverProfileController(
    repository: repo,
    photoService: photoService,
    driverId: driverId,
  );
});
