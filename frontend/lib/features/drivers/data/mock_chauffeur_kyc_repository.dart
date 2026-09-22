import '../../../../core/errors/failures.dart';
import '../../../../core/result/result.dart';
import '../../home/data/mock_repositories.dart';
import '../domain/entities/chauffeur_kyc_application.dart';
import '../domain/repositories/chauffeur_kyc_repository.dart';
import '../domain/entities/driver_profile.dart';

/// In-memory mock implementation of [ChauffeurKycRepository].
///
/// Seeded with pending applicants whose driver IDs map onto the shared
/// [MockDriverRepository] roster, so approving an application flips the real
/// profile's verificationStatus to VERIFIED (visible on the Chauffeur Profile).
class MockChauffeurKycRepository implements ChauffeurKycRepository {
  final Map<String, ChauffeurKycApplication> _applications = {};
  final MockDriverRepository driverRepository;

  MockChauffeurKycRepository({required this.driverRepository}) {
    _seedApplications();
  }

  void _seedApplications() {
    final applicants = [
      (
        id: 'kyc_app_1',
        driverId: 'd7',
        name: 'Gurpreet Singh',
        license: 'DL-04202100892',
        vehicle: 'Mercedes S-Class (DL-01-AB-1234)',
        police: 'Verified (Delhi Police)',
        attire: 'Passed (Royal Bandhgala & Gold Safa)',
      ),
      (
        id: 'kyc_app_2',
        driverId: 'd8',
        name: 'Harish Rawat',
        license: 'DL-09201900451',
        vehicle: 'BMW 5 Series (DL-02-CD-5678)',
        police: 'Verified (Gurugram Police)',
        attire: 'Passed (Ceremonial Safa Inspected)',
      ),
      (
        id: 'kyc_app_3',
        driverId: 'd9',
        name: 'Amitav Roy',
        license: 'DL-11202200773',
        vehicle: 'Audi A6 (HR-26-EF-9012)',
        police: 'Pending Background Check',
        attire: 'Inspection Due',
      ),
    ];

    for (final a in applicants) {
      _applications[a.id] = ChauffeurKycApplication(
        applicationId: a.id,
        driverId: a.driverId,
        fullName: a.name,
        licenseNumber: a.license,
        vehicleAssigned: a.vehicle,
        policeClearanceStatus: a.police,
        attireInspectionStatus: a.attire,
        submittedAt: DateTime(2026, 9, 10),
      );

      // Ensure roster entries exist so approval has a profile to flip.
      if (MockDriverRepository.getProfileSync(a.driverId) == null) {
        MockDriverRepository.setMockDriver(
          a.driverId,
          DriverProfile(
            id: a.driverId,
            fullName: a.name,
            verificationStatus: 'PENDING',
            isOnline: false,
            experienceYears: 5,
            weddingExperienceYears: 2,
            rating: 0,
            totalTrips: 0,
            operatingArea: 'Delhi NCR',
            identityVerified: false,
            bio: 'Chauffeur applicant undergoing verification review.',
            languages: const ['Hindi'],
          ),
        );
      }
    }
  }

  @override
  Future<Result<List<ChauffeurKycApplication>>> getApplications() async {
    await Future.delayed(const Duration(milliseconds: 120));
    final list = _applications.values.toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return Result.success(list);
  }

  @override
  Future<Result<ChauffeurKycApplication>> approveApplication(
    String applicationId,
  ) async {
    await Future.delayed(const Duration(milliseconds: 180));
    return _adjudicate(applicationId, approve: true);
  }

  @override
  Future<Result<ChauffeurKycApplication>> rejectApplication(
    String applicationId, {
    required String reason,
  }) async {
    await Future.delayed(const Duration(milliseconds: 180));
    return _adjudicate(applicationId, approve: false, reason: reason);
  }

  @override
  Future<Result<ChauffeurKycApplication>> uploadDocument({
    required String applicationId,
    required KycDocumentType documentType,
    required String fileReference,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final application = _applications[applicationId];
    if (application == null) {
      return Result.failure(
        NotFoundFailure('KYC application not found for ID: $applicationId'),
      );
    }
    if (fileReference.trim().isEmpty) {
      return const Result.failure(
        ValidationFailure('Document file reference cannot be empty.'),
      );
    }
    if (application.status != ChauffeurKycStatus.pending) {
      return Result.failure(
        ConflictFailure(
          'Documents can only be uploaded while the application is pending.',
        ),
      );
    }

    final updated = application.copyWith(
      documents: {...application.documents, documentType: fileReference.trim()},
    );
    _applications[applicationId] = updated;
    return Result.success(updated);
  }

  @override
  Future<Result<ChauffeurKycApplication>> getApplication(
    String applicationId,
  ) async {
    await Future.delayed(const Duration(milliseconds: 80));
    final application = _applications[applicationId];
    if (application == null) {
      return Result.failure(
        NotFoundFailure('KYC application not found for ID: $applicationId'),
      );
    }
    return Result.success(application);
  }

  Result<ChauffeurKycApplication> _adjudicate(
    String applicationId, {
    required bool approve,
    String? reason,
  }) {
    final application = _applications[applicationId];
    if (application == null) {
      return Result.failure(
        NotFoundFailure('KYC application not found for ID: $applicationId'),
      );
    }
    if (application.status != ChauffeurKycStatus.pending) {
      return Result.failure(
        ConflictFailure(
          'Application has already been ${application.status.name}. Refresh the queue.',
        ),
      );
    }

    // Flip the real chauffeur profile's verification status (operations-
    // authoritative path; chauffeurs can never self-approve).
    final profile = MockDriverRepository.getProfileSync(application.driverId);
    if (profile != null) {
      MockDriverRepository.setMockDriver(
        application.driverId,
        profile.copyWith(
          verificationStatus: approve ? 'VERIFIED' : 'REJECTED',
          identityVerified: approve,
        ),
      );
    }

    final updated = application.copyWith(
      status: approve
          ? ChauffeurKycStatus.approved
          : ChauffeurKycStatus.rejected,
      rejectionReason: approve
          ? null
          : (reason ?? 'Operational review declined.'),
    );
    _applications[applicationId] = updated;
    return Result.success(updated);
  }
}
