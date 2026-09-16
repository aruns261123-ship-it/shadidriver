import '../../../../core/result/result.dart';
import '../entities/driver_profile.dart';

/// Repository contract for retrieving and editing chauffeur profiles.
abstract interface class DriverProfileRepository {
  Future<Result<DriverProfile>> getProfile(String driverId);

  /// Updates editable chauffeur profile attributes.
  ///
  /// Invariant: Implementation must ensure verificationStatus, rating, and
  /// vehicle authorization cannot be self-elevated.
  Future<Result<DriverProfile>> updateProfile(DriverProfile profile);

  Future<Result<String>> updateProfilePhoto({
    required String driverId,
    required String photoUrl,
  });
}
