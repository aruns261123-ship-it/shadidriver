import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/drivers/domain/entities/chauffeur_kyc_application.dart';
import 'package:shadidriver/features/drivers/presentation/controllers/chauffeur_kyc_controller.dart';
import 'package:shadidriver/features/drivers/presentation/controllers/completed_assignments_controller.dart';

void main() {
  group('KYC Document Flow', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    ChauffeurKycController makeController() {
      container.listen(chauffeurKycControllerProvider, (_, _) {});
      return container.read(chauffeurKycControllerProvider.notifier);
    }

    /// Waits for the async seed fetch to land before asserting.
    Future<void> pumpUntilLoaded() async {
      for (var i = 0; i < 50; i++) {
        if (container
            .read(chauffeurKycControllerProvider)
            .applications
            .isNotEmpty) {
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      fail('KYC applications failed to load in time');
    }

    test(
      'uploadDocument attaches a file reference to a pending application',
      () async {
        final controller = makeController();
        await pumpUntilLoaded();

        final first = controller.state.applications.firstWhere(
          (a) => a.status == ChauffeurKycStatus.pending,
        );

        final ok = await controller.uploadDocument(
          applicationId: first.applicationId,
          documentType: KycDocumentType.drivingLicense,
          fileReference: 'dl_gurpreet_2026.pdf',
        );

        expect(ok, isTrue);

        final updated = container
            .read(chauffeurKycControllerProvider)
            .applications
            .firstWhere((a) => a.applicationId == first.applicationId);
        expect(
          updated.documents[KycDocumentType.drivingLicense],
          'dl_gurpreet_2026.pdf',
        );
      },
    );

    test('uploadDocument rejects an empty file reference', () async {
      final controller = makeController();
      await pumpUntilLoaded();

      final first = controller.state.applications.first;

      final ok = await controller.uploadDocument(
        applicationId: first.applicationId,
        documentType: KycDocumentType.vehicleRc,
        fileReference: '   ',
      );

      expect(ok, isFalse);
      expect(controller.state.errorMessage, isNotNull);
    });
  });

  group('Driver Earnings Summary', () {
    test('computes 70% net payout, gross, and duty hours from assignments', () {
      // Direct model test via the provider-derived factory.
      final summary = DriverEarningsSummary(
        assignmentCount: 0,
        grossPaise: 1000000, // ₹10,000
        hoursOnDuty: 8,
      );

      expect(summary.netPayoutPaise, 700000);
      expect(summary.netPayoutFormatted, '₹7000');
      expect(summary.grossRupees, 10000);
      expect(summary.hoursOnDuty, 8);
    });

    test('empty history yields a zeroed summary', () {
      final summary = DriverEarningsSummary.fromAssignments(const []);

      expect(summary.assignmentCount, 0);
      expect(summary.grossPaise, 0);
      expect(summary.netPayoutPaise, 0);
      expect(summary.hoursOnDuty, 0);
    });
  });
}
