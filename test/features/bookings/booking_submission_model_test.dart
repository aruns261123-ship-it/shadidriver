import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_draft.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_status.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_submission_request.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_submission_result.dart';

void main() {
  group('Booking Submission Models & Status Tests', () {
    test('BookingStatus provides user-facing non-confirmed labels', () {
      expect(BookingStatus.requested.displayLabel, equals('Request Submitted'));
      expect(
        BookingStatus.requested.customerSubtitle,
        contains('Awaiting chauffeur confirmation'),
      );
      expect(BookingStatus.confirmed.displayLabel, equals('Booking Confirmed'));
      expect(
        BookingStatus.paymentPending.displayLabel,
        equals('Payment Pending'),
      );
    });

    test(
      'BookingSubmissionRequest.fromDraft builds valid request from complete draft',
      () {
        final draft =
            BookingDraft.initial(
              vehicleId: 'v1',
              vehicleName: 'BMW 5 Series',
              vehicleClass: 'Luxury Sedan',
              chauffeurId: 'd1',
              basePricePaise: 2500000,
              estimatedTotalPaise: 2500000,
              advanceTokenPaise: 500000,
              advanceTokenLabel: '20% Token Deposit',
            ).copyWith(
              ceremonyType: 'Vidai',
              ceremonialAttire: 'Royal Bandhgala',
              pickupAddress: 'The Oberoi Hotel, New Delhi',
              destinationAddress: 'Grand Imperial Banquets, MG Road',
              venueName: 'The Imperial Ballroom',
              landmark: 'Near Gate 2',
              primaryContactName: 'Vikram Malhotra',
              primaryContactPhone: '9810012345',
              passengerCount: 3,
            );

        expect(draft.isComplete, isTrue);

        final request = BookingSubmissionRequest.fromDraft(
          draft,
          idempotencyKey: 'idem_key_xyz',
        );

        expect(request.draftId, equals(draft.id));
        expect(request.vehicleId, equals('v1'));
        expect(request.vehicleName, equals('BMW 5 Series'));
        expect(request.ceremonyType, equals('Vidai'));
        expect(request.ceremonialAttire, equals('Royal Bandhgala'));
        expect(request.pickupAddress, equals('The Oberoi Hotel, New Delhi'));
        expect(
          request.destinationAddress,
          equals('Grand Imperial Banquets, MG Road'),
        );
        expect(request.primaryContactName, equals('Vikram Malhotra'));
        expect(request.primaryContactPhone, equals('9810012345'));
        expect(request.estimatedTotalPaise, equals(2500000));
        expect(request.advanceTokenPaise, equals(500000));
        expect(request.advanceTokenLabel, equals('20% Token Deposit'));
        expect(request.idempotencyKey, equals('idem_key_xyz'));
        expect(request.isValid, isTrue);
      },
    );

    test('BookingSubmissionRequest.isValid blocks incomplete requests', () {
      final incompleteRequest = BookingSubmissionRequest(
        draftId: 'd1',
        vehicleId: '', // Invalid
        vehicleName: 'BMW 5 Series',
        vehicleClass: 'Luxury Sedan',
        chauffeurId: 'd1',
        ceremonyType: 'Baraat',
        ceremonialAttire: 'Bandhgala',
        eventDate: DateTime(2026, 11, 20),
        startTimeHour: 16,
        startTimeMinute: 0,
        durationHours: 8,
        city: 'Delhi NCR',
        pickupAddress: '', // Invalid
        destinationAddress: '',
        primaryContactName: '',
        primaryContactPhone: '',
        passengerCount: 2,
        basePricePaise: 0,
        estimatedTotalPaise: 0,
        advanceTokenPaise: 0,
        idempotencyKey: '',
      );

      expect(incompleteRequest.isValid, isFalse);
    });

    test('BookingSubmissionResult value equality works correctly', () {
      final now = DateTime.now();
      final res1 = BookingSubmissionResult(
        bookingId: 'bk_1',
        bookingReference: 'SD-2026-0001',
        status: BookingStatus.requested,
        submittedAt: now,
        vehicleId: 'v1',
        vehicleName: 'BMW 5 Series',
        vehicleClass: 'Luxury Sedan',
        chauffeurId: 'd1',
        ceremonyType: 'Baraat',
        ceremonialAttire: 'Bandhgala',
        eventDate: now,
        durationHours: 8,
        pickupAddress: 'Pickup',
        destinationAddress: 'Destination',
        primaryContactName: 'Contact',
        primaryContactPhone: '9810012345',
        estimatedTotalPaise: 2500000,
        advanceTokenPaise: 500000,
        nextStepMessage: 'Under review',
      );

      final res2 = BookingSubmissionResult(
        bookingId: 'bk_1',
        bookingReference: 'SD-2026-0001',
        status: BookingStatus.requested,
        submittedAt: now,
        vehicleId: 'v1',
        vehicleName: 'BMW 5 Series',
        vehicleClass: 'Luxury Sedan',
        chauffeurId: 'd1',
        ceremonyType: 'Baraat',
        ceremonialAttire: 'Bandhgala',
        eventDate: now,
        durationHours: 8,
        pickupAddress: 'Pickup',
        destinationAddress: 'Destination',
        primaryContactName: 'Contact',
        primaryContactPhone: '9810012345',
        estimatedTotalPaise: 2500000,
        advanceTokenPaise: 500000,
        nextStepMessage: 'Under review',
      );

      expect(res1 == res2, isTrue);
      expect(res1.hashCode, equals(res2.hashCode));
    });
  });
}
