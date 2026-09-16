import '../../../../core/result/result.dart';
import '../entities/admin_profile.dart';

/// Repository contract for retrieving and editing administrator profiles.
abstract interface class AdminProfileRepository {
  Future<Result<AdminProfile>> getProfile(String adminId);

  /// Updates allowed contact and display fields only.
  ///
  /// Invariant: Implementation must ensure role, department, and authorization
  /// levels cannot be altered via this interface.
  Future<Result<AdminProfile>> updateContactInfo({
    required String adminId,
    required String fullName,
    required String phone,
  });

  Future<Result<String>> updateProfilePhoto({
    required String adminId,
    required String photoUrl,
  });
}
