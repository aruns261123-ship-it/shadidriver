import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers/app_providers.dart';
import '../../domain/entities/customer_profile.dart';
import '../../domain/repositories/customer_profile_repository.dart';
import '../../domain/services/profile_photo_service.dart';

class CustomerProfileState {
  final CustomerProfile? profile;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final String? successMessage;

  const CustomerProfileState({
    this.profile,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.successMessage,
  });

  CustomerProfileState copyWith({
    CustomerProfile? profile,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return CustomerProfileState(
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

class CustomerProfileController extends StateNotifier<CustomerProfileState> {
  final CustomerProfileRepository repository;
  final ProfilePhotoService photoService;
  final String customerId;

  CustomerProfileController({
    required this.repository,
    required this.photoService,
    required this.customerId,
  }) : super(const CustomerProfileState(isLoading: true)) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    final res = await repository.getProfile(customerId);
    res.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
      (profile) => state = state.copyWith(isLoading: false, profile: profile),
    );
  }

  Future<bool> updateProfile(CustomerProfile updated) async {
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
          successMessage: 'Profile details successfully updated.',
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
          userId: customerId,
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
              customerId: customerId,
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
                    profile: state.profile!.copyWith(profilePhotoUrl: url),
                    successMessage: 'Profile photo updated.',
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
          userId: customerId,
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
              customerId: customerId,
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
                    profile: state.profile!.copyWith(profilePhotoUrl: url),
                    successMessage: 'Profile photo captured and updated.',
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
    await photoService.removePhoto(customerId);
    if (state.profile != null) {
      final updated = CustomerProfile(
        id: state.profile!.id,
        fullName: state.profile!.fullName,
        phone: state.profile!.phone,
        email: state.profile!.email,
        city: state.profile!.city,
        preferredLanguage: state.profile!.preferredLanguage,
        profilePhotoUrl: null,
        emergencyContactName: state.profile!.emergencyContactName,
        emergencyContactPhone: state.profile!.emergencyContactPhone,
        weddingPreferences: state.profile!.weddingPreferences,
        createdAt: state.profile!.createdAt,
        updatedAt: DateTime.now(),
      );
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
            successMessage: 'Profile photo removed.',
          );
          return true;
        },
      );
    }
    state = state.copyWith(isSaving: false);
    return true;
  }
}

final customerProfileControllerProvider =
    StateNotifierProvider.family<
      CustomerProfileController,
      CustomerProfileState,
      String
    >((ref, customerId) {
      final repo = ref.watch(customerProfileRepositoryProvider);
      final photoService = ref.watch(profilePhotoServiceProvider);
      return CustomerProfileController(
        repository: repo,
        photoService: photoService,
        customerId: customerId,
      );
    });
