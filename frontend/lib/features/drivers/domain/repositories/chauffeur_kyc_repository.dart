import '../../../../core/result/result.dart';
import '../entities/chauffeur_kyc_application.dart';

/// Pure Dart domain contract for chauffeur verification (KYC) operations.
///
/// Operations-authoritative: approving or rejecting an application is the only
/// path that mutates a chauffeur's verification status — chauffeurs can never
/// self-approve (mirrors the DriverProfile invariant).
abstract interface class ChauffeurKycRepository {
  /// Fetches all KYC applications for the admin verification queue.
  Future<Result<List<ChauffeurKycApplication>>> getApplications();

  /// Approves an application and flips the chauffeur's verification status
  /// to VERIFIED. Fails if the application is not in PENDING state.
  Future<Result<ChauffeurKycApplication>> approveApplication(
    String applicationId,
  );

  /// Rejects an application with a mandatory operational reason. The
  /// chauffeur's verification status moves to REJECTED.
  Future<Result<ChauffeurKycApplication>> rejectApplication(
    String applicationId, {
    required String reason,
  });

  /// Attaches (or replaces) an uploaded document on the application.
  ///
  /// Driver-side submission path: the demo mock records the file reference;
  /// the real backend will upload to secure storage first.
  Future<Result<ChauffeurKycApplication>> uploadDocument({
    required String applicationId,
    required KycDocumentType documentType,
    required String fileReference,
  });

  /// Fetches a single application by ID (document viewer source).
  Future<Result<ChauffeurKycApplication>> getApplication(
    String applicationId,
  );
}
