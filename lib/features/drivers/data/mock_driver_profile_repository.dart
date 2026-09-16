import '../../../../core/errors/failures.dart';
import '../../../../core/result/result.dart';
import '../domain/entities/driver_profile.dart';
import '../domain/repositories/driver_profile_repository.dart';

/// In-memory development mock for [DriverProfileRepository].
class MockDriverProfileRepository implements DriverProfileRepository {
  final Map<String, DriverProfile> _profiles = {};

  MockDriverProfileRepository() {
    _seedDefaultDriverProfile();
  }

  void _seedDefaultDriverProfile() {
    _profiles['d1'] = const DriverProfile(
      id: 'd1',
      fullName: 'Rajesh Kumar',
      phone: '+91 98100 12345',
      email: 'rajesh.kumar@shadidriver.com',
      verificationStatus: 'UNDER_REVIEW',
      documentStatus: 'DOCUMENTS_SUBMITTED',
      vehicleStatus: 'ASSIGNED_AUDI_A6',
      isOnline: true,
      experienceYears: 12,
      weddingExperienceYears: 8,
      operatingArea: 'Delhi NCR & Jaipur Highway',
      languages: ['Hindi', 'English', 'Punjabi'],
      bio:
          'Senior wedding chauffeur with 12 years of ceremonial experience. Expert in royal Baraat processions and VIP guest hospitality.',
      rating: 4.95,
      totalTrips: 142,
      identityVerified: false,
    );
  }

  @override
  Future<Result<DriverProfile>> getProfile(String driverId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final profile = _profiles[driverId];
    if (profile != null) {
      return Result.success(profile);
    }
    // Fallback creates basic chauffeur profile
    final created = DriverProfile(
      id: driverId,
      fullName: 'Chauffeur $driverId',
      verificationStatus: 'UNDER_REVIEW',
      isOnline: false,
      experienceYears: 3,
      rating: 5.0,
      totalTrips: 0,
    );
    _profiles[driverId] = created;
    return Result.success(created);
  }

  @override
  Future<Result<DriverProfile>> updateProfile(DriverProfile profile) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final existing = _profiles[profile.id];
    if (existing == null) {
      return const Result.failure(NotFoundFailure('Driver profile not found.'));
    }

    // STRICT INVARIANT ENFORCEMENT:
    // Chauffeur cannot self-elevate verificationStatus, identityVerified,
    // documentStatus, vehicleStatus, or rating.
    final sanitized = existing.copyWithEditableFields(
      fullName: profile.fullName,
      phone: profile.phone,
      email: profile.email,
      bio: profile.bio,
      languages: profile.languages,
      experienceYears: profile.experienceYears,
      weddingExperienceYears: profile.weddingExperienceYears,
      operatingArea: profile.operatingArea,
      profileImageUrl: profile.profileImageUrl,
      clearProfileImage: profile.profileImageUrl == null,
    );

    _profiles[profile.id] = sanitized;
    return Result.success(sanitized);
  }

  @override
  Future<Result<String>> updateProfilePhoto({
    required String driverId,
    required String photoUrl,
  }) async {
    await Future.delayed(const Duration(milliseconds: 120));
    final existing = _profiles[driverId];
    if (existing == null) {
      return const Result.failure(NotFoundFailure('Driver profile not found.'));
    }
    final updated = existing.copyWith(profileImageUrl: photoUrl);
    _profiles[driverId] = updated;
    return Result.success(photoUrl);
  }
}
