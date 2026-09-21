import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_draft.dart';

void main() {
  group('BookingDraft Domain Entity Tests', () {
    test(
      'initial factory sets explicit pricing values without calculating percentages',
      () {
        // Explicit values passed in from pricing/policy layer
        final draft = BookingDraft.initial(
          vehicleId: 'v1',
          vehicleName: 'BMW 5 Series',
          vehicleClass: 'Luxury Sedan',
          chauffeurId: 'd1',
          basePricePaise: 3500000,
          estimatedTotalPaise: 3500000,
          advanceTokenPaise: 700000,
          advanceTokenLabel: 'Provisional Advance Token',
        );

        expect(draft.vehicleId, equals('v1'));
        expect(draft.vehicleName, equals('BMW 5 Series'));
        expect(draft.ceremonyType, equals('Baraat'));
        expect(draft.ceremonialAttire, equals('Royal Bandhgala & Gold Safa'));
        expect(draft.durationHours, equals(8));
        expect(draft.city, equals('Delhi NCR'));
        expect(draft.status, equals(BookingDraftStatus.draft));
        expect(draft.basePricePaise, equals(3500000));
        expect(draft.estimatedTotalPaise, equals(3500000));
        expect(draft.advanceTokenPaise, equals(700000));
        expect(draft.advanceTokenLabel, equals('Provisional Advance Token'));
        expect(draft.isComplete, isFalse); // Missing locations and host
      },
    );

    test('step validation getters report accurate validity', () {
      final initialDraft = BookingDraft.initial(
        vehicleId: 'v1',
        vehicleName: 'BMW 5 Series',
        vehicleClass: 'Luxury Sedan',
        chauffeurId: 'd1',
        basePricePaise: 3500000,
        estimatedTotalPaise: 3500000,
        advanceTokenPaise: 700000,
      );

      // Section 1: Ceremony
      expect(initialDraft.isCeremonyValid, isTrue);

      // Section 2: Date & Time
      expect(initialDraft.isDateTimeValid, isTrue);

      // Section 3: Locations (initially empty)
      expect(initialDraft.isLocationsValid, isFalse);

      // Section 4: Passenger details (initially empty)
      expect(initialDraft.isPassengerDetailsValid, isFalse);

      final filledDraft = initialDraft.copyWith(
        pickupAddress: 'The Oberoi, New Delhi',
        destinationAddress: 'Grand Imperial Banquets, MG Road',
        primaryContactName: 'Rajesh Sharma',
        primaryContactPhone: '9876543210',
      );

      expect(filledDraft.isLocationsValid, isTrue);
      expect(filledDraft.isPassengerDetailsValid, isTrue);
      expect(filledDraft.isComplete, isTrue);
    });

    test('endDateTime calculates correctly from startTime and duration', () {
      final date = DateTime(2026, 11, 25);
      const time = TimeOfDay(hour: 16, minute: 30); // 4:30 PM
      const duration = 8;

      final draft = BookingDraft.initial(
        vehicleId: 'v1',
        vehicleName: 'BMW 5 Series',
        vehicleClass: 'Luxury Sedan',
        chauffeurId: 'd1',
        basePricePaise: 3500000,
        estimatedTotalPaise: 3500000,
        advanceTokenPaise: 700000,
      ).copyWith(eventDate: date, startTime: time, durationHours: duration);

      expect(draft.startDateTime, equals(DateTime(2026, 11, 25, 16, 30)));
      expect(draft.endDateTime, equals(DateTime(2026, 11, 26, 0, 30)));
    });

    test('copyWith and value equality work as expected', () {
      final draft1 = BookingDraft.initial(
        vehicleId: 'v1',
        vehicleName: 'BMW 5 Series',
        vehicleClass: 'Luxury Sedan',
        chauffeurId: 'd1',
        basePricePaise: 3500000,
        estimatedTotalPaise: 3500000,
        advanceTokenPaise: 700000,
      );

      final draft2 = draft1.copyWith(
        primaryContactName: 'Vikramaditya',
        primaryContactPhone: '9811122233',
        advanceTokenLabel: 'Custom Token',
      );

      expect(draft2.primaryContactName, equals('Vikramaditya'));
      expect(draft2.primaryContactPhone, equals('9811122233'));
      expect(draft2.advanceTokenLabel, equals('Custom Token'));
      expect(draft1 == draft2, isFalse);

      final draft3 = draft2.copyWith();
      expect(draft2 == draft3, isTrue);
      expect(draft2.hashCode, equals(draft3.hashCode));
    });
  });
}
