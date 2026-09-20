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

    test(
      'reopening existing draft loads all values and preserves draft ID on edit',
      () async {
        final vehicleRepo = MockVehicleRepository();
        final vehicleRes = await vehicleRepo.getVehicleDetails('v1');
        final vehicle = vehicleRes.dataOrNull!;

        // 1. Create and save initial draft
        controller.updateCeremony(
          ceremonyType: 'Vidai',
          attire: 'Classic Black Tuxedo',
          instructions: 'Special slow drive',
        );
        controller.updateLocations(
          city: 'Delhi NCR',
          pickupAddress: 'The Oberoi, New Delhi',
          destinationAddress: 'Grand Imperial Banquets, MG Road',
          venueName: 'Imperial Ballroom',
          landmark: 'Gate 2',
        );
        controller.updatePassengerDetails(
          contactName: 'Vikram Malhotra',
          contactPhone: '9810012345',
          alternatePhone: '9811122233',
          passengerCount: 4,
        );
        await controller.submitDraft();
        final originalDraftId = controller.state.draft.id;

        // 2. Open controller with initialDraftId
        final editController = BookingDraftController(
          bookingRepository: mockRepo,
          pricingPolicy: const DevelopmentBookingPricingPolicy(),
          vehicle: vehicle,
          initialDraftId: originalDraftId,
        );

        // Await async draft load
        await Future<void>.delayed(const Duration(milliseconds: 150));

        expect(editController.state.isEditMode, isTrue);
        expect(editController.state.draft.id, equals(originalDraftId));
        expect(editController.state.draft.ceremonyType, equals('Vidai'));
        expect(
          editController.state.draft.ceremonialAttire,
          equals('Classic Black Tuxedo'),
        );
        expect(
          editController.state.draft.specialInstructions,
          equals('Special slow drive'),
        );
        expect(
          editController.state.draft.pickupAddress,
          equals('The Oberoi, New Delhi'),
        );
        expect(
          editController.state.draft.destinationAddress,
          equals('Grand Imperial Banquets, MG Road'),
        );
        expect(
          editController.state.draft.primaryContactName,
          equals('Vikram Malhotra'),
        );
        expect(
          editController.state.draft.primaryContactPhone,
          equals('9810012345'),
        );
        expect(editController.state.draft.passengerCount, equals(4));
        expect(editController.state.hasUnsavedChanges, isFalse);

        // 3. Mutate values
        editController.updatePassengerDetails(
          contactName: 'Amitabh Bachchan',
          contactPhone: '9876543210',
          passengerCount: 2,
        );
        expect(editController.state.hasUnsavedChanges, isTrue);

        // 4. Save edits
        final saveSuccess = await editController.submitDraft();
        expect(saveSuccess, isTrue);
        expect(editController.state.isUpdateSuccess, isTrue);
        expect(editController.state.hasUnsavedChanges, isFalse);

        // 5. Verify repository has same draft ID with updated values
        final updatedRepoDraft = await mockRepo.getBookingDraft(
          originalDraftId,
        );
        expect(updatedRepoDraft.dataOrNull?.id, equals(originalDraftId));
        expect(
          updatedRepoDraft.dataOrNull?.primaryContactName,
          equals('Amitabh Bachchan'),
        );
        expect(updatedRepoDraft.dataOrNull?.passengerCount, equals(2));
      },
    );

    test(
      'overnight duration calculates correctly and preserves explicit hours',
      () {
        final start = DateTime(2026, 9, 25, 20, 0); // 8:00 PM
        final end = DateTime(2026, 9, 26, 7, 0); // 7:00 AM next day (11 hours)

        controller.updateServiceTiming(startDateTime: start, endDateTime: end);

        expect(controller.state.draft.durationHours, equals(11));
        expect(controller.state.draft.isOvernight, isTrue);
        expect(
          controller.state.draft.formattedDuration,
          equals('11 hrs (Overnight)'),
        );
      },
    );

    test(
      'switching vehicle updates vehicle details and recalculates pricing',
      () async {
        final vehicleRepo = MockVehicleRepository();
        final fortunerRes = await vehicleRepo.getVehicleDetails('v3');
        final fortuner = fortunerRes.dataOrNull!;

        expect(controller.state.draft.vehicleId, equals('v1'));

        controller.updateVehicle(fortuner);

        expect(controller.state.draft.vehicleId, equals('v3'));
        expect(controller.state.draft.vehicleName, equals('Toyota Fortuner'));
        expect(controller.state.draft.vehicleClass, equals('Premium SUV'));
        expect(controller.state.draft.basePricePaise, equals(1800000));
      },
    );

    test('resetUnsavedChanges restores original draft fields', () async {
      final vehicleRepo = MockVehicleRepository();
      final vehicleRes = await vehicleRepo.getVehicleDetails('v1');
      final vehicle = vehicleRes.dataOrNull!;

      controller.updateLocations(
        city: 'Delhi NCR',
        pickupAddress: 'The Oberoi',
        destinationAddress: 'Grand Imperial',
      );
      controller.updatePassengerDetails(
        contactName: 'Original Name',
        contactPhone: '9876543210',
        passengerCount: 2,
      );
      await controller.submitDraft();
      final draftId = controller.state.draft.id;

      final editController = BookingDraftController(
        bookingRepository: mockRepo,
        pricingPolicy: const DevelopmentBookingPricingPolicy(),
        vehicle: vehicle,
        initialDraftId: draftId,
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Change name
      editController.updatePassengerDetails(
        contactName: 'Edited Name',
        contactPhone: '9876543210',
        passengerCount: 2,
      );
      expect(editController.state.hasUnsavedChanges, isTrue);
      expect(
        editController.state.draft.primaryContactName,
        equals('Edited Name'),
      );

      // Discard
      editController.resetUnsavedChanges();
      expect(editController.state.hasUnsavedChanges, isFalse);
      expect(
        editController.state.draft.primaryContactName,
        equals('Original Name'),
      );
    });
  });
}
