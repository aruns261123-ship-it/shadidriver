import 'partner_enums.dart';

/// The partner's own profile — exactly the fields `PartnerService.viewProfile`
/// returns (snake_case wire contract).
class PartnerProfile {
  final String id;
  final String companyName;
  final String? contactName;
  final String? baseCity;
  final List<String> serviceCities;
  final List<String> languagesSpoken;
  final int experienceYears;
  final PartnerVerificationStatus verificationStatus;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? decisionReason;

  /// Extended profile fields (GET /partner/profile envelope).
  final int vehicleCount;
  final int documentCount;

  const PartnerProfile({
    required this.id,
    required this.companyName,
    required this.contactName,
    required this.baseCity,
    required this.serviceCities,
    required this.languagesSpoken,
    required this.experienceYears,
    required this.verificationStatus,
    required this.submittedAt,
    required this.reviewedAt,
    required this.decisionReason,
    this.vehicleCount = 0,
    this.documentCount = 0,
  });

  bool get isVerified => verificationStatus.isApproved;
  bool get isUnderReview =>
      verificationStatus == PartnerVerificationStatus.submitted ||
      verificationStatus == PartnerVerificationStatus.underReview;

  /// Partner status counts shown on the My Fleet header, e.g.
  /// "2 Verified / 1 Under Review / 1 Changes Required".
  static Map<PartnerVerificationStatus, int> tally(
    Iterable<PartnerVerificationStatus> statuses,
  ) {
    final map = <PartnerVerificationStatus, int>{};
    for (final s in statuses) {
      map[s] = (map[s] ?? 0) + 1;
    }
    return map;
  }
}
