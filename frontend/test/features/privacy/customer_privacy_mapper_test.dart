import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_submission_request.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_submission_result.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_summary.dart';
import 'package:shadidriver/features/bookings/domain/entities/group_booking.dart';
import 'package:shadidriver/features/vehicles/domain/entities/vehicle_details.dart';
import 'package:shadidriver/features/vehicles/domain/entities/vehicle_summary.dart';

import '../../support/privacy/hostile_api_harness.dart';
import '../../support/privacy/privacy_sentinels.dart';

/// CUSTOMER SERIALIZER CONTRACT (real repositories, hostile payloads).
///
/// The backend strips private fields before the wire; these tests prove the
/// client does not DEPEND on that. A payload that still carries chauffeur
/// identity, partner identity, registration plates or internal keys must map
/// into customer models that simply have nowhere to put them.
void main() {
  group('booking detail / history mapper', () {
    late BookingSummary summary;

    setUp(() async {
      final repo = HostileApiHarness.bookingRepository(
        hostileCustomerBookingPayload(),
      );
      final result = await repo.getBookingById('bk_hostile_1');
      summary = result.dataOrNull!;
    });

    test('keeps every customer-safe booking field', () {
      expect(summary.id, 'bk_hostile_1');
      expect(summary.reference, 'SD-2026-0199');
      expect(summary.status, 'CONFIRMED');
      expect(summary.vehicleName, 'BMW 5 Series SD-DEL-00042');
      expect(
        summary.chauffeurVerification,
        'Vehicle and chauffeur verified by ShadiDriver',
      );
      expect(summary.totalAmountCents, 3500000);
      expect(summary.advanceTokenCents, 700000);
    });

    test('never decodes a chauffeur identity, even from a hostile payload', () {
      expect(summary.chauffeurName, isEmpty);
      expect(PrivacySentinels.isPresentIn(summary.chauffeurName), isFalse);
      // The customer model exposes no field that could carry the rest, so the
      // hostile block has nowhere to land.
      expect(PrivacySentinels.isPresentIn(summary.startOtp), isFalse);
    });
  });

  group('group booking mapper', () {
    late GroupBooking group;

    setUp(() async {
      final repo = HostileApiHarness.bookingRepository(
        hostileCustomerGroupPayload(),
      );
      final result = await repo.getGroupBooking('grp_hostile_1');
      group = result.dataOrNull!;
    });

    test('keeps the convoy the customer owns', () {
      expect(group.bookingReference, 'SD-GRP-2026-000199');
      expect(group.totalVehicles, 1);
      expect(group.assignments.single.vehicleModel, 'Toyota Innova Crysta');
      expect(group.assignments.single.vehicleName, contains('SD-DEL-00001'));
      expect(group.assignments.single.chauffeurAssigned, isTrue);
      expect(group.assignments.single.pricePaise, 5625000);
    });

    test('drops chauffeur, partner and plate identity from every assignment', () {
      final assignment = group.assignments.single;
      expect(assignment.chauffeurName, isNull);
      expect(assignment.chauffeurId, isNull);
      expect(assignment.ownerName, isEmpty);
      // The displayed name is model + opaque fleet code, never the plate.
      expect(PrivacySentinels.isPresentIn(assignment.vehicleName), isFalse);
      expect(PrivacySentinels.isPresentIn(assignment.vehicleId), isFalse);
    });
  });

  group('vehicle mapper', () {
    test('a hostile public payload yields no private vehicle data', () async {
      final repo = HostileApiHarness.vehicleRepository(hostileVehiclePayload());
      final details = (await repo.getVehicleDetails('veh_hostile_1'))
          .dataOrNull as VehicleDetails;

      expect(details.make, 'BMW');
      expect(details.model, '5 Series');
      expect(details.hasVerifiedChauffeur, isTrue);
      expect(details.galleryUrls, ['/media/vehicles/bmw.png']);
      // `VehicleDetails` has no field that could carry the hostile block, and
      // nothing was smuggled into a display field.
      expect(PrivacySentinels.isPresentIn(details.suitabilityInfo), isFalse);

      final VehicleSummary summary =
          (await repo.getVehicleById('veh_hostile_1')).dataOrNull!;
      expect(summary.make, 'BMW');
      expect(
        PrivacySentinels.isPresentIn(summary.registrationNumber),
        isFalse,
        reason: 'the public summary must not carry the registration plate',
      );
    });
  });

  group('booking submission mapper', () {
    test('a hostile submission response carries no identity into the result',
        () async {
      final repo = HostileApiHarness.bookingRepository({
        'success': true,
        'data': {
          'booking': hostileCustomerBookingPayload()['data'],
          'idempotent_replay': false,
        },
      });

      final BookingSubmissionResult submission = (await repo.submitBooking(
        _hostileSubmissionRequest(),
      )).dataOrNull!;

      expect(submission.bookingReference, 'SD-2026-0199');
      expect(submission.estimatedTotalPaise, 3500000);
      // The result's chauffeur link comes from the CUSTOMER's own draft (empty
      // in the real flow) — never from a driver object in the response.
      expect(submission.chauffeurId, isEmpty);
      expect(PrivacySentinels.isPresentIn(submission.nextStepMessage), isFalse);
    });
  });
}

BookingSubmissionRequest _hostileSubmissionRequest() => BookingSubmissionRequest(
  draftId: 'draft_hostile_1',
  vehicleId: 'veh_hostile_1',
  vehicleName: 'BMW 5 Series',
  vehicleClass: 'Luxury Sedan',
  // The real customer flow never names a chauffeur.
  chauffeurId: '',
  ceremonyType: 'Baraat',
  ceremonialAttire: 'Safa & Bandhgala',
  specialInstructions: 'Royal entrance',
  serviceStartDateTime: DateTime(2026, 11, 20, 10, 30),
  serviceEndDateTime: DateTime(2026, 11, 20, 18, 30),
  city: 'Delhi NCR',
  pickupAddress: 'Sector 15, Gurugram',
  destinationAddress: 'The Leela Palace, New Delhi',
  venueName: 'The Leela Palace',
  primaryContactName: 'Aarav Sharma',
  primaryContactPhone: '+919810000001',
  passengerCount: 4,
  basePricePaise: 3500000,
  estimatedTotalPaise: 3955000,
  advanceTokenPaise: 988750,
  idempotencyKey: 'privacy-harness-key-0001',
);
