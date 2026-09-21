import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers/app_providers.dart';
import '../../domain/entities/saved_address.dart';
import '../../domain/repositories/saved_addresses_repository.dart';

class SavedAddressesState {
  final List<SavedAddress> addresses;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final String? successMessage;

  const SavedAddressesState({
    this.addresses = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.successMessage,
  });

  SavedAddressesState copyWith({
    List<SavedAddress>? addresses,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return SavedAddressesState(
      addresses: addresses ?? this.addresses,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages
          ? null
          : (successMessage ?? this.successMessage),
    );
  }
}

class SavedAddressesController extends StateNotifier<SavedAddressesState> {
  final SavedAddressesRepository repository;
  final String customerId;

  SavedAddressesController({required this.repository, required this.customerId})
    : super(const SavedAddressesState(isLoading: true)) {
    loadAddresses();
  }

  Future<void> loadAddresses() async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    final res = await repository.getAddresses(customerId);
    res.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
      (list) => state = state.copyWith(isLoading: false, addresses: list),
    );
  }

  Future<bool> addAddress(SavedAddress address) async {
    state = state.copyWith(isSaving: true, clearMessages: true);
    final res = await repository.addAddress(address);
    return res.fold(
      (failure) {
        state = state.copyWith(isSaving: false, errorMessage: failure.message);
        return false;
      },
      (created) {
        final updatedList = List<SavedAddress>.from(state.addresses);
        if (created.isDefault) {
          for (int i = 0; i < updatedList.length; i++) {
            if (updatedList[i].isDefault) {
              updatedList[i] = updatedList[i].copyWith(isDefault: false);
            }
          }
        }
        updatedList.add(created);
        state = state.copyWith(
          isSaving: false,
          addresses: updatedList,
          successMessage: 'Address saved successfully.',
        );
        return true;
      },
    );
  }

  Future<bool> updateAddress(SavedAddress address) async {
    state = state.copyWith(isSaving: true, clearMessages: true);
    final res = await repository.updateAddress(address);
    return res.fold(
      (failure) {
        state = state.copyWith(isSaving: false, errorMessage: failure.message);
        return false;
      },
      (saved) {
        final updatedList = state.addresses.map((a) {
          if (a.id == saved.id) {
            return saved;
          }
          if (saved.isDefault && a.isDefault) {
            return a.copyWith(isDefault: false);
          }
          return a;
        }).toList();

        state = state.copyWith(
          isSaving: false,
          addresses: updatedList,
          successMessage: 'Address updated successfully.',
        );
        return true;
      },
    );
  }

  Future<bool> deleteAddress(String addressId) async {
    state = state.copyWith(isSaving: true, clearMessages: true);
    final res = await repository.deleteAddress(
      customerId: customerId,
      addressId: addressId,
    );
    return res.fold(
      (failure) {
        state = state.copyWith(isSaving: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        final updatedList = state.addresses
            .where((a) => a.id != addressId)
            .toList();
        state = state.copyWith(
          isSaving: false,
          addresses: updatedList,
          successMessage: 'Address removed.',
        );
        return true;
      },
    );
  }
}

final savedAddressesControllerProvider =
    StateNotifierProvider.family<
      SavedAddressesController,
      SavedAddressesState,
      String
    >((ref, customerId) {
      final repo = ref.watch(savedAddressesRepositoryProvider);
      return SavedAddressesController(repository: repo, customerId: customerId);
    });
