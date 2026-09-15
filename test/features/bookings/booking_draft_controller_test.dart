import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_pricing_policy.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_repository.dart';
import 'package:shadidriver/features/bookings/presentation/controllers/booking_draft_controller.dart';
import 'package:shadidriver/features/home/data/mock_repositories.dart';

void main() {
  group('BookingDraftController Tests', () {
    late MockBookingRepository mockRepo;
    late BookingDraftController controller;

    setUp(() async {
      mockRepo = MockBookingRepository();
      final vehicleRepo = MockVehicleRepository();
      final vehicleRes = await vehicleRepo.getVehicleDetails('v1');
      final vehicle = vehicleRes.dataOrNull!;

      controller = BookingDraftController(
        bookingRepository: mockRepo,
        pricingPolicy: const DevelopmentBookingPricingPolicy(),
        vehicle: vehicle,
      );
    });

    test('initial state has step 0 and initial draft values', () {
      expect(controller.state.activeStep, equals(0));
      expect(controller.state.draft.vehicleId, equals('v1'));
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.isSaved, isFalse);
      expect(controller.state.errorMessage, isNull);
    });

    test('updateCeremony updates ceremonyType and attire', () {
      controller.updateCeremony(
        ceremonyType: 'Vidai',
        attire: 'Classic Black Tuxedo',
        instructions: 'Gentle handling of luggage',
      );

      expect(controller.state.draft.ceremonyType, equals('Vidai'));
      expect(
        controller.state.draft.ceremonialAttire,
        equals('Classic Black Tuxedo'),
      );
      expect(
        controller.state.draft.specialInstructions,
        equals('Gentle handling of luggage'),
      );
    });

    test('updateDateTime delegates to pricing policy', () {
      // 4 hours (short ceremony): policy returns 70% of base (2,500,000 * 0.7 = 1,750,000)
      controller.updateDateTime(
        date: DateTime(2026, 12, 1),
        startTime: const TimeOfDay(hour: 17, minute: 0),
        durationHours: 4,
      );

      expect(controller.state.draft.durationHours, equals(4));
      expect(controller.state.draft.estimatedTotalPaise, equals(1750000));
      expect(controller.state.draft.advanceTokenPaise, equals(350000));

      // 12 hours (full day): base + (4 extra hours * 15% rate) = 2,500,000 + 1,500,000 = 4,000,000
      controller.updateDateTime(
        date: DateTime(2026, 12, 1),
        startTime: const TimeOfDay(hour: 10, minute: 0),
        durationHours: 12,
      );

      expect(controller.state.draft.durationHours, equals(12));
      expect(controller.state.draft.estimatedTotalPaise, equals(4000000));
      expect(controller.state.draft.advanceTokenPaise, equals(800000));
    });

    test(
      'controller consumes custom injected BookingPricingPolicy values dynamically',
      () async {
        final vehicleRepo = MockVehicleRepository();
        final vehicleRes = await vehicleRepo.getVehicleDetails('v1');
        final vehicle = vehicleRes.dataOrNull!;

        // Custom development policy with 10% token and custom label
        const customPolicy = DevelopmentBookingPricingPolicy(
          advancePaymentPolicy: DevelopmentAdvancePaymentPolicy(
            advancePercentage: 0.10,
            advanceTokenLabel: 'Provisional Token (10%)',
          ),
          shortPackageMultiplier: 0.50,
        );

        final customController = BookingDraftController(
          bookingRepository: mockRepo,
          pricingPolicy: customPolicy,
          vehicle: vehicle,
        );

        // Base is 2,500,000 paise. 10% token = 250,000 paise
        expect(
          customController.state.draft.estimatedTotalPaise,
          equals(2500000),
        );
        expect(customController.state.draft.advanceTokenPaise, equals(250000));
        expect(
          customController.state.draft.advanceTokenLabel,
          equals('Provisional Token (10%)'),
        );

        // Update to 4 hours: 50% of base = 1,250,000, 10% token = 125,000
        customController.updateDateTime(
          date: DateTime(2026, 12, 1),
          startTime: const TimeOfDay(hour: 17, minute: 0),
          durationHours: 4,
        );

        expect(
          customController.state.draft.estimatedTotalPaise,
          equals(1250000),
        );
        expect(customController.state.draft.advanceTokenPaise, equals(125000));
      },
    );

    test('step progression blocks transition if validation fails', () {
      // Step 0 valid by default, can go to Step 1
      final canGoStep1 = controller.nextStep();
      expect(canGoStep1, isTrue);
      expect(controller.state.activeStep, equals(1));

      // Step 1 valid by default, can go to Step 2
      final canGoStep2 = controller.nextStep();
      expect(canGoStep2, isTrue);
      expect(controller.state.activeStep, equals(2));

      // Step 2 has empty locations -> should fail and remain on Step 2
      final canGoStep3 = controller.nextStep();
      expect(canGoStep3, isFalse);
      expect(controller.state.activeStep, equals(2));
      expect(controller.state.errorMessage, contains('pickup address'));

      // Fill locations
      controller.updateLocations(
        city: 'Delhi NCR',
        pickupAddress: 'The Oberoi, New Delhi',
        destinationAddress: 'Grand Imperial Banquets, MG Road',
      );

      // Now should advance to Step 3
      final canGoStep3AfterFill = controller.nextStep();
      expect(canGoStep3AfterFill, isTrue);
      expect(controller.state.activeStep, equals(3));
      expect(controller.state.errorMessage, isNull);
    });

    test('submitDraft persists draft when all fields are valid', () async {
      // Fill all required sections
      controller.updateLocations(
        city: 'Delhi NCR',
        pickupAddress: 'The Oberoi, New Delhi',
        destinationAddress: 'Grand Imperial Banquets, MG Road',
      );
      controller.updatePassengerDetails(
        contactName: 'Rajesh Sharma',
        contactPhone: '9876543210',
        passengerCount: 3,
      );

      expect(controller.state.draft.isComplete, isTrue);

      final success = await controller.submitDraft();
      expect(success, isTrue);
      expect(controller.state.isSaved, isTrue);
      expect(controller.state.savedDraft, isNotNull);
      expect(
        controller.state.savedDraft?.primaryContactName,
        equals('Rajesh Sharma'),
      );

      // Verify draft in repository
      final repoDraft = await mockRepo.getBookingDraft(
        controller.state.draft.id,
      );
      expect(repoDraft.isSuccess, isTrue);
      expect(repoDraft.dataOrNull?.vehicleId, equals('v1'));
    });
  });
}
