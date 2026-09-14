/// Driver profile domain representation.
class DriverProfile {
  final String id;
  final String fullName;
  final String verificationStatus;
  final bool isOnline;
  final int experienceYears;
  final double rating;
  final int totalTrips;

  const DriverProfile({
    required this.id,
    required this.fullName,
    required this.verificationStatus,
    required this.isOnline,
    required this.experienceYears,
    required this.rating,
    required this.totalTrips,
  });
}
