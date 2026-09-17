import '../../../../features/reviews/domain/entities/review_summary.dart';

/// Driver profile domain representation for customer, chauffeur console, and admin evaluation.
///
/// Invariant: [verificationStatus], [identityVerified], and [rating] are strictly
/// server/operations controlled and cannot be self-modified by the chauffeur.
class DriverProfile {
  final String id;
  final String fullName;
  final String phone;
  final String? email;
  final String verificationStatus;
  final String documentStatus;
  final String vehicleStatus;
  final bool isOnline;
  final int experienceYears;
  final double rating;
  final int totalTrips;
  final String bio;
  final List<String> languages;
  final int weddingExperienceYears;
  final String operatingArea;
  final bool identityVerified;
  final List<ReviewSummary> recentReviews;
  final String? profileImageUrl;

  const DriverProfile({
    required this.id,
    required this.fullName,
    this.phone = '+91 98100 12345',
    this.email = 'rajesh.kumar@shadidriver.com',
    required this.verificationStatus,
    this.documentStatus = 'DOCUMENTS_SUBMITTED',
    this.vehicleStatus = 'ASSIGNED_AUDI_A6',
    required this.isOnline,
    required this.experienceYears,
    required this.rating,
    required this.totalTrips,
    this.bio = '',
    this.languages = const [],
    this.weddingExperienceYears = 0,
    this.operatingArea = '',
    this.identityVerified = false,
    this.recentReviews = const [],
    this.profileImageUrl,
  });

  /// Structured profile completion percentage (0–100%).
  ///
  /// CRITICAL ARCHITECTURAL RULE:
  /// Completion percentage is calculated purely from filled profile content
  /// and is strictly decoupled from [verificationStatus].
  int get completionPercentage {
    int score = 0;
    if (fullName.trim().length >= 2) score += 15;
    if (phone.trim().length >= 10) score += 15;
    if (profileImageUrl != null && profileImageUrl!.trim().isNotEmpty) {
      score += 15;
    }
    if (bio.trim().length >= 10) score += 15;
    if (operatingArea.trim().isNotEmpty) score += 10;
    if (experienceYears > 0) score += 10;
    if (weddingExperienceYears > 0) score += 10;
    if (languages.isNotEmpty) score += 10;
    return score.clamp(0, 100);
  }

  /// List of non-sensitive missing items needed for 100% profile completion.
  List<String> get missingProfileItems {
    final missing = <String>[];
    if (fullName.trim().length < 2) missing.add('Full Name');
    if (phone.trim().length < 10) missing.add('Phone Number');
    if (profileImageUrl == null || profileImageUrl!.trim().isEmpty) {
      missing.add('Profile Photo');
    }
    if (bio.trim().length < 10) missing.add('Chauffeur Bio');
    if (operatingArea.trim().isEmpty) missing.add('Operating Area');
    if (experienceYears <= 0) missing.add('Total Experience');
    if (weddingExperienceYears <= 0) missing.add('Wedding Experience');
    if (languages.isEmpty) missing.add('Spoken Languages');
    return missing;
  }

  /// Whether all essential professional profile attributes are filled.
  bool get isProfileComplete => missingProfileItems.isEmpty;

  /// Driver editing method that strictly preserves verification and platform invariants.
  DriverProfile copyWithEditableFields({
    String? fullName,
    String? phone,
    String? email,
    String? bio,
    List<String>? languages,
    int? experienceYears,
    int? weddingExperienceYears,
    String? operatingArea,
    String? profileImageUrl,
    bool clearProfileImage = false,
  }) {
    return DriverProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      verificationStatus: verificationStatus, // protected
      documentStatus: documentStatus, // protected
      vehicleStatus: vehicleStatus, // protected
      isOnline: isOnline,
      experienceYears: experienceYears ?? this.experienceYears,
      rating: rating, // protected
      totalTrips: totalTrips, // protected
      bio: bio ?? this.bio,
      languages: languages ?? this.languages,
      weddingExperienceYears:
          weddingExperienceYears ?? this.weddingExperienceYears,
      operatingArea: operatingArea ?? this.operatingArea,
      identityVerified: identityVerified, // protected
      recentReviews: recentReviews, // protected
      profileImageUrl: clearProfileImage
          ? null
          : (profileImageUrl ?? this.profileImageUrl),
    );
  }

  DriverProfile copyWith({
    String? id,
    String? fullName,
    String? phone,
    String? email,
    String? verificationStatus,
    String? documentStatus,
    String? vehicleStatus,
    bool? isOnline,
    int? experienceYears,
    double? rating,
    int? totalTrips,
    String? bio,
    List<String>? languages,
    int? weddingExperienceYears,
    String? operatingArea,
    bool? identityVerified,
    List<ReviewSummary>? recentReviews,
    String? profileImageUrl,
    bool clearProfileImage = false,
  }) {
    return DriverProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      documentStatus: documentStatus ?? this.documentStatus,
      vehicleStatus: vehicleStatus ?? this.vehicleStatus,
      isOnline: isOnline ?? this.isOnline,
      experienceYears: experienceYears ?? this.experienceYears,
      rating: rating ?? this.rating,
      totalTrips: totalTrips ?? this.totalTrips,
      bio: bio ?? this.bio,
      languages: languages ?? this.languages,
      weddingExperienceYears:
          weddingExperienceYears ?? this.weddingExperienceYears,
      operatingArea: operatingArea ?? this.operatingArea,
      identityVerified: identityVerified ?? this.identityVerified,
      recentReviews: recentReviews ?? this.recentReviews,
      profileImageUrl: clearProfileImage
          ? null
          : (profileImageUrl ?? this.profileImageUrl),
    );
  }
}
