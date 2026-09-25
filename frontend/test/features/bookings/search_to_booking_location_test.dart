import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/bookings/data/dto/submit_booking_dto.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_repository.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_submission_request.dart';
import 'package:shadidriver/features/bookings/domain/entities/search_handoff.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_pricing_policy.dart';
import 'package:shadidriver/features/bookings/domain/policies/service_category_policy.dart';
import 'package:shadidriver/features/bookings/presentation/controllers/booking_draft_controller.dart';
import 'package:shadidriver/features/vehicles/domain/entities/pricing_summary.dart';
import 'package:shadidriver/features/vehicles/domain/entities/vehicle_details.dart';

const _vehicleUuid = '661bfb4b-4ac7-44b2-9b8b-76e7a29dd66e';

VehicleDetails _vehicle() => const VehicleDetails(
  id: _vehicleUuid,
  make: 'Toyota',
  model: 'Innova Crysta',
  year: 2023,
  vehicleClass: 'Executive MPV',
  seatingCapacity: 6,
  transmission: 'AUTOMATIC',
  verificationStatus: 'APPROVED',
  galleryUrls: [],
  suitabilityInfo: 'Guest transport benchmark.',
  suitableCeremonies: ['Guest Transport'],
  amenities: ['Dual AC'],
  ceremonialAddons: [],
  pricing: PricingSummary(basePriceCents: 2500000, billingUnit: 'DAY'),
  rating: 4.9,
  reviewCount: 120,
  isAvailableNow: true,
);

/// Search → Search Results → Vehicle Selection → Booking Draft → Submit.
///
/// The customer types pickup and destination once; those values must reach the
/// server unchanged (never re-asked, never dropped, never replaced by defaults).
void main() {
  test('search intent reaches the submitted wire payload intact', () {
    const handoff = SearchHandoff(
      pickupLocation: 'Sector 15, Gurugram',
      destination: 'The Leela Palace, Chanakyapuri, New Delhi',
      occasion: 'Guest Transport',
      passengerCount: 6,
    );

    final controller = BookingDraftController(
      bookingRepository: MockBookingRepository(),
      pricingPolicy: DevelopmentBookingPricingPolicy(),
      vehicle: _vehicle(),
      searchHandoff: handoff,
    );

    final draft = controller.state.draft;
    expect(draft.pickupAddress, 'Sector 15, Gurugram');
    expect(draft.destinationAddress, 'The Leela Palace, Chanakyapuri, New Delhi');
    expect(draft.ceremonyType, 'Guest Transport');
    expect(draft.passengerCount, 6);
    // The chosen fleet asset is carried too — the customer never re-picks it.
    expect(draft.vehicleId, _vehicleUuid);

    final request = BookingSubmissionRequest.fromDraft(
      draft.copyWith(
        primaryContactName: 'Aarav Sharma',
        primaryContactPhone: '+919810000001',
      ),
      idempotencyKey: 'bk-search-handoff-0001',
    );
    expect(request.isValid, isTrue, reason: request.validationMessage ?? '');

    final json = SubmitBookingDto.fromDomain(
      request,
      serviceCategoryId: ServiceCategoryPolicy.forCeremony(
        request.ceremonyType,
      ),
    ).toJson();

    expect(json['pickupAddress'], 'Sector 15, Gurugram');
    expect(
      json['destinationAddress'],
      'The Leela Palace, Chanakyapuri, New Delhi',
    );
    expect(json['city'], 'Delhi NCR');
    expect(json['passengerCount'], 6);
    expect(json['vehicleTypeId'], _vehicleUuid);
    // The backend only declares four seeded service categories, so a ceremony
    // outside them (Guest Transport) falls back to the seeded default rather
    // than inventing an id the server would reject.
    expect(json['serviceCategoryId'], ServiceCategoryPolicy.baraat);
  });

  test('every offerable occasion maps onto a declared service category', () {
    // The values the search screen offers, and the ids the backend declares.
    const declared = {
      ServiceCategoryPolicy.baraat,
      ServiceCategoryPolicy.vidai,
      ServiceCategoryPolicy.reception,
      ServiceCategoryPolicy.airportVip,
    };
    const occasions = [
      'Baraat',
      'Vidai',
      'Bride Entry',
      'Groom Entry',
      'Guest Transport',
      'Photoshoot',
      'Airport VIP',
      'Reception',
    ];

    for (final occasion in occasions) {
      expect(
        declared,
        contains(ServiceCategoryPolicy.forCeremony(occasion)),
        reason: '$occasion must map to a seeded category id',
      );
    }
    expect(ServiceCategoryPolicy.forCeremony('Vidai'), ServiceCategoryPolicy.vidai);
    expect(
      ServiceCategoryPolicy.forCeremony('Airport VIP'),
      ServiceCategoryPolicy.airportVip,
    );
    expect(
      ServiceCategoryPolicy.forCeremony('Reception'),
      ServiceCategoryPolicy.reception,
    );
  });

  test('a search that only supplies one address keeps the other intact', () {
    final controller = BookingDraftController(
      bookingRepository: MockBookingRepository(),
      pricingPolicy: DevelopmentBookingPricingPolicy(),
      vehicle: _vehicle(),
      searchHandoff: const SearchHandoff(
        pickupLocation: 'The Oberoi, Dr Zakir Hussain Marg, New Delhi',
      ),
    );

    expect(
      controller.state.draft.pickupAddress,
      'The Oberoi, Dr Zakir Hussain Marg, New Delhi',
    );
    // Nothing invented for the missing side.
    expect(controller.state.draft.destinationAddress, '');
    expect(controller.state.draft.locationValidationMessage, isNotNull);
  });
}
