import '../../../../features/reviews/domain/entities/review_summary.dart';

/// Driver profile domain representation for customer and admin evaluation.
class DriverProfile {
  final String id;
  final String fullName;
  final String verificationStatus;
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
    required this.verificationStatus,
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
}
