import 'package:flutter/foundation.dart';

/// Lifecycle status of a chauffeur KYC application.
enum ChauffeurKycStatus { pending, approved, rejected }

/// Canonical KYC document types collected during chauffeur onboarding
/// (roadmap Phase 2A).
enum KycDocumentType { drivingLicense, vehicleRc, insuranceCertificate, policeNoc }

extension KycDocumentTypeLabel on KycDocumentType {
  String get label => switch (this) {
        KycDocumentType.drivingLicense => 'Driving License',
        KycDocumentType.vehicleRc => 'Vehicle RC',
        KycDocumentType.insuranceCertificate => 'Insurance Certificate',
        KycDocumentType.policeNoc => 'Police NOC',
      };
}

/// Domain representation of a chauffeur verification (KYC) application.
///
/// Sourced from the driver onboarding pipeline and adjudicated by operations:
/// police clearance, ceremonial attire inspection, and vehicle assignment are
/// audited before the chauffeur's [verificationStatus] flips to APPROVED.
@immutable
class ChauffeurKycApplication {
  final String applicationId;
  final String driverId;
  final String fullName;
  final String licenseNumber;
  final String vehicleAssigned;
  final String policeClearanceStatus;
  final String attireInspectionStatus;
  final ChauffeurKycStatus status;
  final String? rejectionReason;
  final DateTime submittedAt;

  /// Uploaded verification documents: type → file name/reference.
  /// Demo mock stores file names; the real backend swaps in secure URLs.
  final Map<KycDocumentType, String> documents;

  const ChauffeurKycApplication({
    required this.applicationId,
    required this.driverId,
    required this.fullName,
    required this.licenseNumber,
    required this.vehicleAssigned,
    required this.policeClearanceStatus,
    required this.attireInspectionStatus,
    this.status = ChauffeurKycStatus.pending,
    this.rejectionReason,
    required this.submittedAt,
    this.documents = const {},
  });

  ChauffeurKycApplication copyWith({
    ChauffeurKycStatus? status,
    String? rejectionReason,
    Map<KycDocumentType, String>? documents,
  }) {
    return ChauffeurKycApplication(
      applicationId: applicationId,
      driverId: driverId,
      fullName: fullName,
      licenseNumber: licenseNumber,
      vehicleAssigned: vehicleAssigned,
      policeClearanceStatus: policeClearanceStatus,
      attireInspectionStatus: attireInspectionStatus,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      submittedAt: submittedAt,
      documents: documents ?? this.documents,
    );
  }
}
