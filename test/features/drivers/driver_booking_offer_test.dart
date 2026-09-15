import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_pricing_policy.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_status.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_submission_result.dart';
import 'package:shadidriver/features/drivers/domain/entities/driver_booking_offer.dart';

void main() {
  group('DriverBookingOffer Domain & Privacy Tests', () {
    final pricingPolicy = DevelopmentBookingPricingPolicy();

    BookingSubmissionResult createSampleResult({
      String contactName = 'Vikram Malhotra',
      String contactPhone = '9810012345',
      int estimatedTotalPaise = 2500000,
    }) {
      return BookingSubmissionResult(
        bookingId: 'bk_sample_01',
        bookingReference: 'SD-2026-0042',
        status: BookingStatus.requested,
        submittedAt: DateTime(2026, 9, 15, 12, 0),
        vehicleId: 'v1',
        vehicleName: 'BMW 5 Series',
        vehicleClass: 'Luxury Sedan',
        chauffeurId: 'd1',
        ceremonyType: 'Baraat',
        ceremonialAttire: 'Royal Bandhgala & Gold Safa',
        eventDate: DateTime(2026, 11, 20),
        durationHours: 8,
        pickupAddress: 'The Oberoi, New Delhi',
        destinationAddress: 'Grand Imperial Banquets, MG Road',
        primaryContactName: contactName,
        primaryContactPhone: contactPhone,
        estimatedTotalPaise: estimatedTotalPaise,
        advanceTokenPaise: 500000,
        advanceTokenLabel: 'Advance Token (20%)',
        nextStepMessage: 'Awaiting Chauffeur Confirmation',
      );
    }

    test(
      'correctly constructs offer and maps fields from BookingSubmissionResult',
      () {
        final result = createSampleResult();
        final offer = DriverBookingOffer.fromBookingSubmissionResult(
          result,
          pricingPolicy,
          passengerCount: 3,
        );

        expect(offer.bookingId, equals('bk_sample_01'));
        expect(offer.bookingReference, equals('SD-2026-0042'));
        expect(offer.status, equals(BookingStatus.requested));
        expect(offer.ceremonyType, equals('Baraat'));
        expect(offer.ceremonialAttire, equals('Royal Bandhgala & Gold Safa'));
        expect(offer.vehicleName, equals('BMW 5 Series'));
        expect(offer.vehicleClass, equals('Luxury Sedan'));
        expect(offer.durationHours, equals(8));
        expect(offer.passengerCount, equals(3));
        expect(offer.pickupAddress, equals('The Oberoi, New Delhi'));
        expect(
          offer.destinationAddress,
          equals('Grand Imperial Banquets, MG Road'),
        );
        expect(offer.estimatedTotalPaise, equals(2500000));
        // 80% of 2500000 = 2000000
        expect(offer.estimatedDriverEarningsPaise, equals(2000000));
      },
    );

    test('enforces DPDP privacy rules by masking customer contact name', () {
      final offerMultiPart = DriverBookingOffer.fromBookingSubmissionResult(
        createSampleResult(contactName: 'Vikram Malhotra'),
        pricingPolicy,
      );
      expect(offerMultiPart.maskedContactName, equals('Host: Vikram M.'));

      final offerSinglePart = DriverBookingOffer.fromBookingSubmissionResult(
        createSampleResult(contactName: 'Rajesh'),
        pricingPolicy,
      );
      expect(offerSinglePart.maskedContactName, equals('Host: Rajesh'));

      final offerEmpty = DriverBookingOffer.fromBookingSubmissionResult(
        createSampleResult(contactName: ''),
        pricingPolicy,
      );
      expect(offerEmpty.maskedContactName, equals('Host'));
    });

    test(
      'enforces DPDP privacy rules by masking phone number before acceptance',
      () {
        final offer = DriverBookingOffer.fromBookingSubmissionResult(
          createSampleResult(contactPhone: '9810012345'),
          pricingPolicy,
        );
        expect(offer.maskedContactPhone, equals('+91 ••••• ••345'));
        expect(offer.maskedContactPhone.contains('9810012'), isFalse);

        final shortOffer = DriverBookingOffer.fromBookingSubmissionResult(
          createSampleResult(contactPhone: '12'),
          pricingPolicy,
        );
        expect(shortOffer.maskedContactPhone, equals('+91 ••••• •••••'));
      },
    );
  });
}
