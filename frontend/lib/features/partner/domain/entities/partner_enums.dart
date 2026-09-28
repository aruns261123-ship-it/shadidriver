/// Verification state shared by partners, vehicles and documents.
///
/// Wire values mirror `VerificationStatus` in the backend Prisma schema.
enum PartnerVerificationStatus {
  pendingSubmission('PENDING_SUBMISSION'),
  submitted('SUBMITTED'),
  underReview('UNDER_REVIEW'),
  approved('APPROVED'),
  actionRequired('ACTION_REQUIRED'),
  rejected('REJECTED'),
  suspended('SUSPENDED'),
  documentExpired('DOCUMENT_EXPIRED');

  const PartnerVerificationStatus(this.wire);
  final String wire;

  static PartnerVerificationStatus fromWire(String? raw) =>
      PartnerVerificationStatus.values.firstWhere(
        (s) => s.wire == raw,
        orElse: () => PartnerVerificationStatus.pendingSubmission,
      );

  /// Customer-bookable state. An APPROVED partner is not necessarily an
  /// APPROVED fleet — the two are always rendered separately.
  bool get isApproved => this == PartnerVerificationStatus.approved;
}

/// Pricing tariff review state (`PricingStatus` wire values).
enum TariffStatus {
  pendingReview('PENDING_REVIEW'),
  approved('APPROVED'),
  rejected('REJECTED'),
  superseded('SUPERSEDED'),
  active('ACTIVE');

  const TariffStatus(this.wire);
  final String wire;

  static TariffStatus fromWire(String? raw) => TariffStatus.values
      .firstWhere((s) => s.wire == raw, orElse: () => TariffStatus.pendingReview);
}
