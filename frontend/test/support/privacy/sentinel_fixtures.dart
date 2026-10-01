import 'package:shadidriver/core/result/result.dart';
import 'package:shadidriver/core/theme/shadi_imagery.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_repository.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_draft.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_status.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_submission_result.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_summary.dart';
import 'package:shadidriver/features/bookings/domain/entities/customer_fleet_intent.dart';
import 'package:shadidriver/features/bookings/domain/entities/group_booking.dart';
import 'package:shadidriver/features/bookings/domain/entities/vehicle_assignment.dart';
import 'package:shadidriver/features/search/domain/entities/search_query.dart';
import 'package:shadidriver/features/search/domain/entities/search_sort.dart';
import 'package:shadidriver/features/vehicles/domain/entities/pricing_summary.dart';
import 'package:shadidriver/features/vehicles/domain/entities/vehicle_details.dart';
import 'package:shadidriver/features/vehicles/domain/entities/vehicle_summary.dart';
import 'package:shadidriver/features/vehicles/domain/repositories/vehicle_repository.dart';

import 'privacy_sentinels.dart';

/// Fixtures whose PRIVATE fields are populated with unmistakable sentinels.
///
/// The point is not that these objects look realistic — it is that if any
/// customer-facing widget, mapper or accessibility label ever starts reading a
/// private field, the sentinel appears and the privacy test fails loudly.
/// Every fixture is asserted to actually carry its sentinel (`assertFixtureIs
/// Dangerous` below), so a fixture cannot silently become safe and make a
/// privacy test pass for the wrong reason.

// ---------------------------------------------------------------- bookings

BookingSummary dangerousBookingSummary({
  String id = 'bk_private_1',
  String status = 'CONFIRMED',
}) => BookingSummary(
  id: id,
  reference: 'SD-2026-0101',
  serviceCategory: 'SVC_BARAAT',
  status: status,
  eventStartTime: DateTime(2026, 11, 20, 10, 30),
  eventEndTime: DateTime(2026, 11, 20, 18, 30),
  pickupAddress: 'The Oberoi, Dr Zakir Hussain Marg, New Delhi',
  destinationAddress: 'The Leela Palace, Chanakyapuri, New Delhi',
  routeDistanceKm: 24.5,
  vehicleName: 'BMW 5 Series SD-DEL-00042',
  // PRIVATE (legacy/admin only): the customer view never carries these.
  chauffeurName: PrivacySentinels.driverName,
  chauffeurVerification: 'Vehicle and chauffeur verified by ShadiDriver',
  totalAmountCents: 3500000,
  advanceTokenCents: 700000,
  version: 2,
);

BookingSubmissionResult dangerousSubmissionResult({
  String id = 'bk_private_1',
}) => BookingSubmissionResult(
  bookingId: id,
  bookingReference: 'SD-2026-0101',
  status: BookingStatus.requested,
  submittedAt: DateTime(2026, 9, 30, 6, 0),
  vehicleId: 'veh-1',
  vehicleName: 'BMW 5 Series',
  vehicleClass: 'Luxury Sedan',
  // PRIVATE (legacy): the draft/submission link to a driver, never displayed.
  chauffeurId: PrivacySentinels.driverId,
  ceremonyType: 'Baraat',
  ceremonialAttire: 'Royal Bandhgala & Gold Safa',
  serviceStartDateTime: DateTime(2026, 11, 20, 16, 0),
  serviceEndDateTime: DateTime(2026, 11, 20, 22, 0),
  routeDistanceKm: 24.5,
  pickupAddress: 'The Oberoi Hotel, New Delhi',
  destinationAddress: 'Grand Imperial Banquets, MG Road',
  primaryContactName: 'Vikram Malhotra',
  primaryContactPhone: '9810012345',
  estimatedTotalPaise: 2500000,
  advanceTokenPaise: 500000,
  advanceTokenLabel: 'Advance Token (20%)',
  // Operations-owned guidance — the only identity-adjacent copy a customer sees.
  nextStepMessage:
      'Your ceremonial reservation request has been received. Our operations '
      'team is confirming vehicle and chauffeur allocation.',
);

BookingDraft dangerousBookingDraft({String id = 'draft_private_1'}) =>
    BookingDraft.initial(
      vehicleId: 'veh-1',
      vehicleName: 'BMW 5 Series',
      vehicleClass: 'Luxury Sedan',
      // PRIVATE (legacy): never rendered by a customer surface.
      chauffeurId: PrivacySentinels.driverId,
      basePricePaise: 2500000,
      estimatedTotalPaise: 2500000,
      advanceTokenPaise: 500000,
      advanceTokenLabel: 'Advance Token',
    ).copyWith(
      id: id,
      ceremonyType: 'Baraat',
      ceremonialAttire: 'Royal Bandhgala & Gold Safa',
      specialInstructions: 'Ceremonial slow drive',
      pickupAddress: 'The Oberoi Hotel, New Delhi',
      destinationAddress: 'Grand Imperial Banquets, MG Road',
      venueName: 'Imperial Ballroom',
      landmark: 'Gate 2',
      primaryContactName: 'Vikram Malhotra',
      primaryContactPhone: '9810012345',
      alternateContactPhone: '9811122233',
      passengerCount: 2,
      createdAt: DateTime(2026, 9, 30, 6, 0),
    );

VehicleAssignment dangerousAssignment({
  required int sequence,
  required String parentBookingId,
}) => VehicleAssignment(
  assignmentId: 'asg_$sequence',
  parentBookingId: parentBookingId,
  vehicleId: 'veh_$sequence',
  vehicleName: 'Toyota Innova Crysta SD-DEL-0000$sequence',
  vehicleModel: 'Toyota Innova Crysta',
  capacity: 6,
  // PRIVATE: fleet partner identity is internal operational data.
  ownerName: PrivacySentinels.partnerName,
  // PRIVATE: chauffeur link + name are never shown to a customer.
  chauffeurId: '${PrivacySentinels.driverId}_$sequence',
  chauffeurName: PrivacySentinels.driverName,
  chauffeurAssigned: true,
  pricePaise: 5625000,
  status: 'CHAUFFEUR_ASSIGNED',
);

GroupBooking dangerousGroupBooking({String id = 'grp_private_1'}) => GroupBooking(
  parentBookingId: id,
  bookingReference: 'SD-GRP-2026-000123',
  status: BookingStatus.customerConfirmationPending,
  customerIntent: CustomerFleetIntent.mixed(
    passengerCount: 12,
    units: const {'Toyota Innova Crysta': 2},
  ),
  totalPassengers: 12,
  totalVehicles: 2,
  assignments: [
    dangerousAssignment(sequence: 1, parentBookingId: id),
    dangerousAssignment(sequence: 2, parentBookingId: id),
  ],
  ceremonyType: 'Baraat',
  serviceStartDateTime: DateTime(2026, 11, 20, 10, 0),
  serviceEndDateTime: DateTime(2026, 11, 20, 22, 0),
  city: 'Delhi NCR',
  pickupAddress: 'Sector 15, Gurugram',
  destinationAddress: 'The Leela Palace, New Delhi',
  estimatedTotalPaise: 11250000,
  advanceTokenPaise: 2812500,
  requirements: const ['Wedding decoration'],
  communicationPreference: 'WHATSAPP',
  createdAt: DateTime(2026, 9, 30, 6, 0),
);

// ---------------------------------------------------------------- vehicles

VehicleSummary dangerousVehicleSummary({String id = 'veh-1'}) => VehicleSummary(
  id: id,
  vehicleTypeId: 'VT_BMW5',
  make: 'BMW',
  model: '5 Series',
  year: 2024,
  vehicleClass: 'Luxury Sedan',
  // PRIVATE: registration plates are internal (the fleet reference is public).
  registrationNumber: PrivacySentinels.registrationPlate,
  seatingCapacity: 4,
  verificationStatus: 'APPROVED',
  imageUrl: ShadiImagery.primary,
  rating: 4.8,
  reviewCount: 21,
  hasVerifiedChauffeur: true,
  pricing: const PricingSummary(basePriceCents: 2188, billingUnit: 'KM'),
  transmission: 'AUTOMATIC',
  amenities: const ['Dual AC', 'Charging Ports'],
  isAvailableNow: true,
);

VehicleDetails dangerousVehicleDetails({String id = 'veh-1'}) => VehicleDetails(
  id: id,
  vehicleTypeId: 'VT_BMW5',
  make: 'BMW',
  model: '5 Series',
  year: 2024,
  vehicleClass: 'Luxury Sedan',
  seatingCapacity: 4,
  transmission: 'AUTOMATIC',
  verificationStatus: 'APPROVED',
  galleryUrls: const [ShadiImagery.primary],
  fuelType: 'Petrol',
  serviceAreas: const ['Delhi NCR'],
  suitabilityInfo: 'Ceremonial arrivals',
  suitableCeremonies: const ['Baraat'],
  amenities: const ['Dual AC', 'Charging Ports'],
  ceremonialAddons: const [],
  pricing: const PricingSummary(basePriceCents: 2188, billingUnit: 'KM'),
  hasVerifiedChauffeur: true,
  rating: 4.8,
  reviewCount: 21,
  isAvailableNow: true,
);

// ------------------------------------------------------------ repositories

/// Booking repository whose every read carries private sentinels.
class SentinelBookingRepository extends MockBookingRepository {
  SentinelBookingRepository();

  final BookingSummary summary = dangerousBookingSummary();
  final BookingSubmissionResult submission = dangerousSubmissionResult();
  final GroupBooking group = dangerousGroupBooking();
  final BookingDraft draft = dangerousBookingDraft();

  @override
  Future<Result<BookingSummary>> getBookingById(String bookingId) async =>
      Result.success(summary);

  @override
  Future<Result<List<BookingSummary>>> getMyBookings({
    int page = 1,
    int limit = 20,
    String? statusFilter,
  }) async => Result.success([summary]);

  @override
  Future<Result<BookingSubmissionResult?>> getSubmissionResult(
    String bookingId,
  ) async => Result.success(submission);

  @override
  Future<Result<GroupBooking?>> getGroupBooking(String parentBookingId) async =>
      Result.success(group);

  @override
  Future<Result<BookingDraft?>> getBookingDraft(String draftId) async =>
      Result.success(draft);
}

/// Vehicle repository whose reads are customer-safe while the summary fixture
/// still carries a private registration plate.
class SentinelVehicleRepository implements VehicleRepository {
  final VehicleSummary summary = dangerousVehicleSummary();
  final VehicleDetails details = dangerousVehicleDetails();

  @override
  Future<Result<List<VehicleSummary>>> getAvailableVehicles({
    String? categoryId,
    DateTime? eventStartTime,
    DateTime? eventEndTime,
  }) async => Result.success([summary]);

  @override
  Future<Result<List<VehicleSummary>>> getFeaturedVehicles() async =>
      Result.success([summary]);

  @override
  Future<Result<VehicleSummary>> getVehicleById(String vehicleId) async =>
      Result.success(summary);

  @override
  Future<Result<VehicleDetails>> getVehicleDetails(String vehicleId) async =>
      Result.success(details);

  @override
  Future<Result<List<VehicleSummary>>> searchVehicles({
    required VehicleSearchQuery query,
    required SearchSort sort,
  }) async => Result.success([summary]);
}

/// Proves a fixture is genuinely dangerous before a privacy test relies on it.
///
/// Throws (rather than `assert`-ing) so the guarantee holds in every test mode.
void assertFixtureIsDangerous() {
  final dangerousValues = <Object?>[
    dangerousBookingSummary().chauffeurName,
    dangerousSubmissionResult().chauffeurId,
    dangerousBookingDraft().chauffeurId,
    dangerousGroupBooking().assignments.first.ownerName,
    dangerousGroupBooking().assignments.first.chauffeurName,
    dangerousGroupBooking().assignments.first.chauffeurId,
    dangerousVehicleSummary().registrationNumber,
  ];
  for (final value in dangerousValues) {
    if (!PrivacySentinels.isPresentIn(value)) {
      throw StateError(
        'Fixture value "$value" does not carry a sentinel — the privacy test '
        'would pass vacuously.',
      );
    }
  }
}
