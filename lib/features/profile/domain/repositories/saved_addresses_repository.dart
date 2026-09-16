import '../../../../core/result/result.dart';
import '../entities/saved_address.dart';

/// Repository contract for managing customer saved addresses.
abstract interface class SavedAddressesRepository {
  /// Fetches all saved addresses for [customerId].
  Future<Result<List<SavedAddress>>> getAddresses(String customerId);

  /// Saves a new address for the customer.
  Future<Result<SavedAddress>> addAddress(SavedAddress address);

  /// Updates an existing address.
  Future<Result<SavedAddress>> updateAddress(SavedAddress address);

  /// Deletes a saved address by [addressId].
  Future<Result<void>> deleteAddress({
    required String customerId,
    required String addressId,
  });
}
