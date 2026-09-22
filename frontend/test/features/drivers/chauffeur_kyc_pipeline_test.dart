import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/features/drivers/domain/entities/chauffeur_kyc_application.dart';
import 'package:shadidriver/features/drivers/domain/entities/driver_duty_status.dart';
import 'package:shadidriver/features/drivers/presentation/controllers/chauffeur_kyc_controller.dart';
import 'package:shadidriver/features/home/data/mock_repositories.dart';

void main() {
  late MockDriverRepository driverStore;
  late ProviderContainer container;

  setUp(() {
    driverStore = MockDriverRepository();
    container = ProviderContainer(
      overrides: [driverRepositoryProvider.overrideWithValue(driverStore)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  ChauffeurKycController makeController() {
    container.listen(chauffeurKycControllerProvider, (_, _) {});
    return container.read(chauffeurKycControllerProvider.notifier);
  }

  group('Chauffeur KYC Pipeline', () {
    test('loads seeded pending applications', () async {
      final controller = makeController();
      await controller.loadApplications();

      expect(controller.state.applications, hasLength(3));
      expect(controller.state.pendingCount, 3);
      expect(
        controller.state.applications.every(
          (a) => a.status == ChauffeurKycStatus.pending,
        ),
        isTrue,
      );
    });

    test('approval flips the chauffeur profile to VERIFIED', () async {
      final controller = makeController();
      await controller.loadApplications();

      final applicant = controller.state.applications.first;
      final ok = await controller.approve(applicant.applicationId);

      expect(ok, isTrue);
      expect(applicant.status, ChauffeurKycStatus.pending); // local copy stale

      final updated = controller.state.applications.first;
      expect(updated.status, ChauffeurKycStatus.approved);
      expect(controller.state.pendingCount, 2);

      // The REAL roster profile is now verified — this is the whole point.
      final profile = MockDriverRepository.getProfileSync(applicant.driverId);
      expect(profile, isNotNull);
      expect(profile!.verificationStatus, 'VERIFIED');
      expect(profile.identityVerified, isTrue);
    });

    test('rejection requires a reason and flips status to REJECTED', () async {
      final controller = makeController();
      await controller.loadApplications();

      final applicant = controller.state.applications.first;
      final ok = await controller.reject(
        applicant.applicationId,
        reason: 'Police clearance could not be validated.',
      );

      expect(ok, isTrue);
      final updated = controller.state.applications.first;
      expect(updated.status, ChauffeurKycStatus.rejected);
      expect(updated.rejectionReason, contains('Police clearance'));

      final profile = MockDriverRepository.getProfileSync(applicant.driverId);
      expect(profile!.verificationStatus, 'REJECTED');
      expect(profile.identityVerified, isFalse);
    });

    test('adjudicating twice conflicts without corrupting state', () async {
      final controller = makeController();
      await controller.loadApplications();

      final applicant = controller.state.applications.first;
      await controller.approve(applicant.applicationId);

      // Second approval attempt via the repository path must fail.
      final repo = container.read(chauffeurKycRepositoryProvider);
      final second = await repo.approveApplication(applicant.applicationId);
      expect(second.isFailure, isTrue);

      // State keeps the first (successful) decision.
      expect(
        controller.state.applications.first.status,
        ChauffeurKycStatus.approved,
      );
    });

    test('approved chauffeur profile loads through the roster', () async {
      final controller = makeController();
      await controller.loadApplications();
      final applicant = controller.state.applications.first;
      await controller.approve(applicant.applicationId);

      final profileResult = await driverStore.getDriverById(applicant.driverId);
      expect(profileResult.dataOrNull, isNotNull);
      expect(profileResult.dataOrNull!.verificationStatus, 'VERIFIED');
      // Sanity: duty status API unaffected by verification changes.
      final duty = await driverStore.getDutyStatus(applicant.driverId);
      expect(duty.dataOrNull, DriverDutyStatus.available);
    });
  });
}
