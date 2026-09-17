import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_repository.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_status.dart';
import 'package:shadidriver/features/bookings/domain/entities/customer_fleet_intent.dart';
import 'package:shadidriver/features/bookings/domain/entities/group_booking_submission_request.dart';

void main() {
  late MockBookingRepository repo;

  setUp(() {
    repo = MockBookingRepository();
  });

  group('CustomerFleetIntent Domain Model', () {
    test('single vehicle intent identifies as singleVehicle', () {
      final intent = CustomerFleetIntent.single(
        passengerCount: 3,
        model: 'BMW 5 Series',
      );

      expect(intent.bookingType, equals(FleetBookingType.singleVehicle));
      expect(intent.totalRequestedUnits, equals(1));
      expect(intent.preferredModel, equals('BMW 5 Series'));
    });

    test(
      'same model multiple intent identifies as sameVehicleMultiple (e.g. 7 x Innova)',
      () {
        final intent = CustomerFleetIntent.sameModelMultiple(
          passengerCount: 40,
          model: 'Toyota Innova Crysta',
          count: 7,
        );

        expect(
          intent.bookingType,
          equals(FleetBookingType.sameVehicleMultiple),
        );
        expect(intent.totalRequestedUnits, equals(7));
        expect(intent.preferredModel, equals('Toyota Innova Crysta'));
        expect(intent.requestedUnits['Toyota Innova Crysta'], equals(7));
      },
    );

    test(
      'mixed fleet intent identifies as mixedFleet (4 Innova, 3 Camry, 1 BMW)',
      () {
        final intent = CustomerFleetIntent.mixed(
          passengerCount: 40,
          units: {
            'Toyota Innova Crysta': 4,
            'Toyota Camry': 3,
            'BMW 5 Series': 1,
          },
        );

        expect(intent.bookingType, equals(FleetBookingType.mixedFleet));
        expect(intent.totalRequestedUnits, equals(8));
        expect(intent.requestedUnits.length, equals(3));
      },
    );

    test('anySuitable intent handles guest count automatically', () {
      final intent = CustomerFleetIntent.anySuitable(passengerCount: 25);

      expect(intent.preference, equals(CustomerFleetPreference.anySuitable));
      expect(intent.passengerCount, equals(25));
    });
  });

  group('Fleet Availability Check (No Silent Substitution)', () {
    test(
      'returns available when requested count is within mock inventory',
      () async {
        final intent = CustomerFleetIntent.sameModelMultiple(
          passengerCount: 18,
          model: 'Toyota Innova Crysta',
          count: 3, // Mock inventory has 5
        );

        final result = await repo.checkFleetAvailability(intent);
        expect(result.isSuccess, isTrue);

        final availability = result.dataOrNull!;
        expect(availability.isFullyAvailable, isTrue);
        expect(availability.availableCount, equals(3));
        expect(availability.shortfall, equals(0));
        expect(availability.alternativeSuggestions, isEmpty);
      },
    );

    test(
      'reports shortfall and provides explicit alternatives when inventory is insufficient (7 x Innova vs 5 available)',
      () async {
        final intent = CustomerFleetIntent.sameModelMultiple(
          passengerCount: 40,
          model: 'Toyota Innova Crysta',
          count: 7, // Mock inventory only has 5 -> shortfall of 2
        );

        final result = await repo.checkFleetAvailability(intent);
        expect(result.isSuccess, isTrue);

        final availability = result.dataOrNull!;
        // Must NOT silently substitute
        expect(availability.isFullyAvailable, isFalse);
        expect(availability.requestedCount, equals(7));
        expect(availability.availableCount, equals(5));
        expect(availability.shortfall, equals(2));
        expect(availability.alternativeSuggestions.isNotEmpty, isTrue);

        // Alternatives must provide capacity
        final alt = availability.alternativeSuggestions.first;
        expect(alt.suggestedCount, equals(2));
        expect(alt.totalCapacity, greaterThanOrEqualTo(8));
      },
    );

    test('mixed fleet checks each requested model inventory', () async {
      final intent = CustomerFleetIntent.mixed(
        passengerCount: 25,
        units: {
          'Toyota Innova Crysta': 2, // 5 available -> OK
          'Toyota Camry': 2, // 4 available -> OK
          'BMW 5 Series': 1, // 3 available -> OK
        },
      );

      final result = await repo.checkFleetAvailability(intent);
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull!.isFullyAvailable, isTrue);
      expect(result.dataOrNull!.shortfall, equals(0));
    });

    test(
      'mixed fleet detects partial shortfall when a model exceeds inventory',
      () async {
        final intent = CustomerFleetIntent.mixed(
          passengerCount: 50,
          units: {
            'Toyota Innova Crysta': 6, // only 5 available -> shortfall of 1
            'BMW 5 Series': 2, // 3 available -> OK
          },
        );

        final result = await repo.checkFleetAvailability(intent);
        expect(result.isSuccess, isTrue);

        final availability = result.dataOrNull!;
        expect(availability.isFullyAvailable, isFalse);
        expect(availability.shortfall, equals(1));
        expect(availability.alternativeSuggestions.isNotEmpty, isTrue);
      },
    );
  });

  group('Parent Group Booking & Vehicle Assignments Persistence', () {
    test(
      'submits same-model group booking (7 x Innova) with individual vehicle assignments',
      () async {
        final intent = CustomerFleetIntent.sameModelMultiple(
          passengerCount: 40,
          model: 'Toyota Innova Crysta',
          count: 7,
        );

        final request = GroupBookingSubmissionRequest(
          fleetIntent: intent,
          ceremonyType: 'Baraat Procession',
          serviceStartDateTime: DateTime(2026, 12, 10, 15, 0),
          serviceEndDateTime: DateTime(2026, 12, 10, 23, 0),
          city: 'New Delhi',
          pickupAddress: 'Taj Palace, Sardar Patel Marg',
          destinationAddress: 'MorBagh Farms, Chattarpur',
          primaryContactName: 'Vikramaditya Oberoi',
          primaryContactPhone: '+91 98110 98110',
          idempotencyKey: 'idemp_grp_7_innova_001',
        );

        final result = await repo.submitGroupBooking(request);
        expect(result.isSuccess, isTrue);

        final groupBooking = result.dataOrNull!;
        expect(groupBooking.parentBookingId, startsWith('grp_'));
        expect(groupBooking.bookingReference, startsWith('SD-GRP-2026-'));
        expect(groupBooking.status, equals(BookingStatus.requested));
        expect(groupBooking.totalPassengers, equals(40));
        expect(groupBooking.totalVehicles, equals(7));
        expect(groupBooking.assignments.length, equals(7));

        // Check vehicle assignments
        for (var i = 0; i < 7; i++) {
          final a = groupBooking.assignments[i];
          expect(a.parentBookingId, equals(groupBooking.parentBookingId));
          expect(a.vehicleModel, equals('Toyota Innova Crysta'));
          expect(a.capacity, equals(6));
          expect(a.pricePaise, equals(2500000));
          expect(a.status, equals('ASSIGNED'));
          expect(a.ownerName, equals('PB Ceremonial Fleet'));
          expect(a.chauffeurName, isNotNull);
        }

        // Total capacity check: 7 x 6 = 42 >= 40 passengers
        expect(groupBooking.totalAllocatedCapacity, equals(42));
        expect(groupBooking.isCapacitySufficient, isTrue);

        // Financials: 7 * 2500000 = 17500000 paise (Rs 1,75,000)
        expect(groupBooking.estimatedTotalPaise, equals(17500000));
        // Advance token: 20% = 3500000 paise (Rs 35,000)
        expect(groupBooking.advanceTokenPaise, equals(3500000));

        // Verify retrieval
        final fetchResult = await repo.getGroupBooking(
          groupBooking.parentBookingId,
        );
        expect(fetchResult.isSuccess, isTrue);
        expect(
          fetchResult.dataOrNull?.parentBookingId,
          equals(groupBooking.parentBookingId),
        );
        expect(fetchResult.dataOrNull?.assignments.length, equals(7));
      },
    );

    test(
      'submits mixed fleet group booking (4 Innova, 3 Camry, 1 BMW) with correct model distribution',
      () async {
        final intent = CustomerFleetIntent.mixed(
          passengerCount: 40,
          units: {
            'Toyota Innova Crysta': 4,
            'Toyota Camry': 3,
            'BMW 5 Series': 1,
          },
        );

        final request = GroupBookingSubmissionRequest(
          fleetIntent: intent,
          ceremonyType: 'VIP Wedding Convoy',
          serviceStartDateTime: DateTime(2026, 12, 12, 10, 0),
          serviceEndDateTime: DateTime(2026, 12, 12, 20, 0),
          city: 'New Delhi',
          pickupAddress: 'The Leela Palace, Chanakyapuri',
          destinationAddress: 'ITC Grand Bharat, Gurugram',
          primaryContactName: 'Ananya Singhania',
          primaryContactPhone: '+91 99990 12345',
          idempotencyKey: 'idemp_grp_mixed_002',
        );

        final result = await repo.submitGroupBooking(request);
        expect(result.isSuccess, isTrue);

        final groupBooking = result.dataOrNull!;
        expect(groupBooking.totalVehicles, equals(8));
        expect(groupBooking.assignments.length, equals(8));

        final byModel = groupBooking.assignmentsByModel;
        expect(byModel['Toyota Innova Crysta']?.length, equals(4));
        expect(byModel['Toyota Camry']?.length, equals(3));
        expect(byModel['BMW 5 Series']?.length, equals(1));

        // Capacity: 4*6 + 3*4 + 1*4 = 24 + 12 + 4 = 40
        expect(groupBooking.totalAllocatedCapacity, equals(40));
        expect(groupBooking.isCapacitySufficient, isTrue);

        // Financials: 4*2500000 + 3*3000000 + 1*4500000 = 10000000 + 9000000 + 4500000 = 23500000 paise (Rs 2,35,000)
        expect(groupBooking.estimatedTotalPaise, equals(23500000));
        expect(groupBooking.advanceTokenPaise, equals(4700000));
      },
    );

    test(
      'idempotency ensures duplicate submission returns cached parent group booking',
      () async {
        final intent = CustomerFleetIntent.single(
          passengerCount: 4,
          model: 'BMW 5 Series',
        );

        final request = GroupBookingSubmissionRequest(
          fleetIntent: intent,
          ceremonyType: 'Groom Entry',
          serviceStartDateTime: DateTime(2026, 12, 15, 17, 0),
          serviceEndDateTime: DateTime(2026, 12, 15, 23, 0),
          city: 'New Delhi',
          pickupAddress: 'Oberoi Grand',
          destinationAddress: 'Royal Palace Grounds',
          primaryContactName: 'Karan Mehra',
          primaryContactPhone: '+91 98111 22233',
          idempotencyKey: 'idemp_duplicate_test_key',
        );

        final first = await repo.submitGroupBooking(request);
        final second = await repo.submitGroupBooking(request);

        expect(first.isSuccess, isTrue);
        expect(second.isSuccess, isTrue);
        expect(
          first.dataOrNull!.parentBookingId,
          equals(second.dataOrNull!.parentBookingId),
        );
        expect(
          first.dataOrNull!.bookingReference,
          equals(second.dataOrNull!.bookingReference),
        );
      },
    );
  });
}
