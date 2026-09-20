import '../../../../core/errors/failures.dart';
import '../../../../core/result/result.dart';
import '../domain/entities/saved_address.dart';
import '../domain/repositories/saved_addresses_repository.dart';

/// In-memory development mock for [SavedAddressesRepository].
class MockSavedAddressesRepository implements SavedAddressesRepository {
  final Map<String, List<SavedAddress>> _storage = {};
  int _idCounter = 100;

  MockSavedAddressesRepository() {
    _seedDefaultAddresses();
  }

  void _seedDefaultAddresses() {
    _storage['cust_101'] = [
      const SavedAddress(
        id: 'addr_1',
        customerId: 'cust_101',
        label: 'Delhi Residence',
        address: 'The Oberoi, Dr Zakir Hussain Marg, New Delhi',
        landmark: 'Near India Gate',
        type: AddressType.home,
        isDefault: true,
      ),
      const SavedAddress(
        id: 'addr_2',
        customerId: 'cust_101',
        label: 'Grand Imperial Banquets',
        address: 'Grand Imperial Banquets, MG Road, Gurugram',
        landmark: 'Gate 2 VIP Porch',
        type: AddressType.weddingVenue,
        isDefault: false,
      ),
    ];
  }

  @override
  Future<Result<List<SavedAddress>>> getAddresses(String customerId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final list = _storage[customerId] ?? [];
    return Result.success(List.unmodifiable(list));
  }

  @override
  Future<Result<SavedAddress>> addAddress(SavedAddress address) async {
    await Future.delayed(const Duration(milliseconds: 150));
    if (!address.isValid) {
      return const Result.failure(
        ValidationFailure('Address label and full address are required.'),
      );
    }

    _idCounter++;
    final newId = address.id.isNotEmpty ? address.id : 'addr_$_idCounter';
    final created = address.copyWith(id: newId);

    final current = _storage.putIfAbsent(address.customerId, () => []);
    // If marked as default, unset other defaults
    if (created.isDefault) {
      for (int i = 0; i < current.length; i++) {
        if (current[i].isDefault) {
          current[i] = current[i].copyWith(isDefault: false);
        }
      }
    }
    current.add(created);

    return Result.success(created);
  }

  @override
  Future<Result<SavedAddress>> updateAddress(SavedAddress address) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final current = _storage[address.customerId];
    if (current == null) {
      return const Result.failure(
        NotFoundFailure('Customer address store not found.'),
      );
    }

    final index = current.indexWhere((a) => a.id == address.id);
    if (index == -1) {
      return const Result.failure(NotFoundFailure('Saved address not found.'));
    }

    if (address.isDefault) {
      for (int i = 0; i < current.length; i++) {
        if (current[i].isDefault && current[i].id != address.id) {
          current[i] = current[i].copyWith(isDefault: false);
        }
      }
    }

    current[index] = address;
    return Result.success(address);
  }

  @override
  Future<Result<void>> deleteAddress({
    required String customerId,
    required String addressId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final current = _storage[customerId];
    if (current != null) {
      current.removeWhere((a) => a.id == addressId);
    }
    return const Result.success(null);
  }
}
