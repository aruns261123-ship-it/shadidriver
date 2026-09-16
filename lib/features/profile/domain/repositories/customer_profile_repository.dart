import '../../../../core/result/result.dart';
import '../entities/customer_profile.dart';

/// Repository contract for retrieving and editing customer profiles.
abstract interface class CustomerProfileRepository {
  Future<Result<CustomerProfile>> getProfile(String customerId);

  Future<Result<CustomerProfile>> updateProfile(CustomerProfile profile);

  Future<Result<String>> updateProfilePhoto({
    required String customerId,
    required String photoUrl,
  });
}
