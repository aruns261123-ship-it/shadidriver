import '../../../../core/errors/failures.dart';
import '../../../../core/result/result.dart';
import '../../vehicles/domain/entities/pricing_summary.dart';
import '../../vehicles/domain/entities/vehicle_details.dart';
import '../../vehicles/domain/entities/vehicle_summary.dart';
import '../../vehicles/domain/repositories/vehicle_repository.dart';
import '../../services/domain/entities/service_category.dart';
import '../../services/domain/entities/service_addon.dart';
import '../../services/domain/repositories/service_category_repository.dart';
import '../../services/domain/repositories/service_addon_repository.dart';
import '../../drivers/domain/entities/driver_duty_status.dart';
import '../../drivers/domain/entities/driver_profile.dart';
import '../../drivers/domain/repositories/driver_repository.dart';
import '../../reviews/domain/entities/review_summary.dart';
import '../../search/domain/entities/search_query.dart';
import '../../search/domain/entities/search_sort.dart';
import '../../search/domain/engines/vehicle_search_engine.dart';

class MockVehicleRepository implements VehicleRepository {
  @override
  Future<Result<List<VehicleSummary>>> getAvailableVehicles({
    String? categoryId,
    DateTime? eventStartTime,
    DateTime? eventEndTime,
  }) async {
    return Result.success(_mockVehicles);
  }

  @override
  Future<Result<List<VehicleSummary>>> getFeaturedVehicles() async {
    return Result.success(_mockVehicles.take(3).toList());
  }

  @override
  Future<Result<VehicleSummary>> getVehicleById(String vehicleId) async {
    try {
      final vehicle = _mockVehicles.firstWhere((v) => v.id == vehicleId);
      return Result.success(vehicle);
    } catch (_) {
      return Result.failure(
        NotFoundFailure('Vehicle not found with ID: $vehicleId'),
      );
    }
  }

  @override
  Future<Result<VehicleDetails>> getVehicleDetails(String vehicleId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final details = _mockDetails[vehicleId];
    if (details != null) {
      return Result.success(details);
    }
    return Result.failure(
      NotFoundFailure('Vehicle details not found for ID: $vehicleId'),
    );
  }

  @override
  Future<Result<List<VehicleSummary>>> searchVehicles({
    required VehicleSearchQuery query,
    required SearchSort sort,
  }) async {
    // Artificial delay to simulate network
    await Future.delayed(const Duration(milliseconds: 600));

    final results = VehicleSearchEngine.search(
      vehicles: _mockVehicles,
      query: query,
      sort: sort,
    );
    return Result.success(results);
  }

  static final Map<String, VehicleDetails> _mockDetails = {
    'v1': const VehicleDetails(
      id: 'v1',
      make: 'BMW',
      model: '5 Series',
      year: 2025,
      vehicleClass: 'Luxury Sedan',
      seatingCapacity: 4,
      transmission: 'AUTOMATIC',
      verificationStatus: 'VERIFIED',
      galleryUrls: [
        'assets/images/vehicles/bmw_5_front.jpg',
        'assets/images/vehicles/bmw_5_interior.jpg',
        'assets/images/vehicles/bmw_5_side.jpg',
      ],
      suitabilityInfo:
          'A benchmark of executive luxury. Engineered for smooth ceremonial transitions with silent cabin acoustics and rear executive climate comfort.',
      suitableCeremonies: ['Baraat', 'Groom Entry', 'Reception', 'Engagement'],
      amenities: [
        'Dual-Zone Rear AC',
        'Ambient Mood Lighting',
        'Mineral Water Bottles',
        'In-Car High-Speed Wi-Fi',
        'Fast Phone Chargers (Type-C / Lightning)',
        'Ceremonial Umbrella',
      ],
      ceremonialAddons: [
        ServiceAddon(
          id: 'addon_baraat_attire',
          name: 'Royal Safa & Bandhgala Attire',
          description:
              'Chauffeur dressed in regal wedding attire tailored to family theme.',
          features: ['Custom Color Safa', 'Bandhgala Suit', 'Formal Etiquette'],
          pricing: PricingSummary(
            basePriceCents: 500000,
            billingUnit: 'PACKAGE',
          ),
        ),
        ServiceAddon(
          id: 'addon_fresh_floral',
          name: 'Non-Damaging Fresh Floral Tie',
          description:
              'Artisanal floral accent on hood and side mirrors using soft magnetic clips.',
          features: [
            'Fresh Orchids / Roses',
            'Paint-Safe Clamps',
            'Florist Window',
          ],
          pricing: PricingSummary(
            basePriceCents: 750000,
            billingUnit: 'PACKAGE',
          ),
        ),
      ],
      pricing: PricingSummary(basePriceCents: 2500000, billingUnit: 'DAY'),
      chauffeurId: 'd1',
      rating: 4.9,
      reviewCount: 128,
      isAvailableNow: true,
    ),
    'v2': const VehicleDetails(
      id: 'v2',
      make: 'Audi',
      model: 'A6',
      year: 2024,
      vehicleClass: 'Premium Sedan',
      seatingCapacity: 4,
      transmission: 'AUTOMATIC',
      verificationStatus: 'VERIFIED',
      galleryUrls: [
        'assets/images/vehicles/audi_a6_front.jpg',
        'assets/images/vehicles/audi_a6_cabin.jpg',
      ],
      suitabilityInfo:
          'Understated elegance with exceptionally smooth suspension, making it the preferred choice for Vidai departures and VIP airport transfers.',
      suitableCeremonies: ['Vidai', 'Bride Entry', 'Airport VIP', 'Reception'],
      amenities: [
        'Four-Zone Deluxe Climate Control',
        'Acoustic Glazing Windows',
        'Plush Leather Seating',
        'Mineral Water & Refreshment Tissues',
        'Multi-Port Device Chargers',
      ],
      ceremonialAddons: [
        ServiceAddon(
          id: 'addon_vidai_quiet',
          name: 'Vidai Muhurat Standby Protocol',
          description:
              'Chauffeur arrives 45 mins prior to muhurat and coordinates via silent app beacon.',
          features: ['Silent Standby', 'Luggage Assistance', 'Umbrella Escort'],
          pricing: PricingSummary(
            basePriceCents: 350000,
            billingUnit: 'PACKAGE',
          ),
        ),
      ],
      pricing: PricingSummary(basePriceCents: 2200000, billingUnit: 'DAY'),
      chauffeurId: 'd2',
      rating: 4.8,
      reviewCount: 95,
      isAvailableNow: false,
    ),
    'v3': const VehicleDetails(
      id: 'v3',
      make: 'Toyota',
      model: 'Fortuner',
      year: 2025,
      vehicleClass: 'Premium SUV',
      seatingCapacity: 7,
      transmission: 'AUTOMATIC',
      verificationStatus: 'VERIFIED',
      galleryUrls: [
        'assets/images/vehicles/fortuner_front.jpg',
        'assets/images/vehicles/fortuner_side.jpg',
      ],
      suitabilityInfo:
          'Commanding road presence with ample 7-seater room and luggage capacity. Perfect for family logistics, inter-venue shuttling, and Baraat entourage.',
      suitableCeremonies: ['Guest Transport', 'Baraat', 'Airport VIP'],
      amenities: [
        'Dual AC with Roof Vents',
        'Spacious 3rd Row Seating',
        'High Ground Clearance for Remote Farmhouses',
        'Drinking Water Storage',
      ],
      ceremonialAddons: [],
      pricing: PricingSummary(basePriceCents: 1800000, billingUnit: 'DAY'),
      chauffeurId: 'd3',
      rating: 4.7,
      reviewCount: 210,
      isAvailableNow: true,
    ),
    'v4': const VehicleDetails(
      id: 'v4',
      make: 'Mercedes-Benz',
      model: 'S-Class',
      year: 2026,
      vehicleClass: 'Luxury Sedan',
      seatingCapacity: 4,
      transmission: 'AUTOMATIC',
      verificationStatus: 'VERIFIED',
      galleryUrls: [
        'assets/images/vehicles/s_class_front.jpg',
        'assets/images/vehicles/s_class_lounge.jpg',
      ],
      suitabilityInfo:
          'The pinnacle of wedding prestige. Featuring executive rear reclining seats, footrests, active noise cancellation, and champagne cooler.',
      suitableCeremonies: [
        'Bride Entry',
        'Groom Entry',
        'Reception',
        'Photoshoot',
      ],
      amenities: [
        'Executive Reclining Lounge Seats',
        'Burmester 3D Surround Audio',
        'In-Cabin Champagne Cooler',
        'Panoramic Sunroof',
        'Hot Stone Massage Function',
      ],
      ceremonialAddons: [],
      pricing: PricingSummary(basePriceCents: 5500000, billingUnit: 'DAY'),
      chauffeurId: 'd1',
      rating: 5.0,
      reviewCount: 45,
      isAvailableNow: true,
    ),
    'v5': const VehicleDetails(
      id: 'v5',
      make: 'Vintage',
      model: 'Rolls Royce Silver Cloud',
      year: 1960,
      vehicleClass: 'Vintage',
      seatingCapacity: 4,
      transmission: 'MANUAL',
      verificationStatus: 'VERIFIED',
      galleryUrls: ['assets/images/vehicles/rolls_vintage.jpg'],
      suitabilityInfo:
          'Timeless royal heritage. Guaranteed to make Baraat and photoshoot entries unforgettable. Accompanied by our senior heritage chauffeur.',
      suitableCeremonies: ['Baraat', 'Groom Entry', 'Photoshoot'],
      amenities: [
        'Restored Velvet Heritage Upholstery',
        'Ceremonial Flower Garland Mounts',
        'Dedicated Processional Chaperone',
      ],
      ceremonialAddons: [],
      pricing: PricingSummary(basePriceCents: 8500000, billingUnit: 'PACKAGE'),
      chauffeurId: 'd4',
      rating: 4.9,
      reviewCount: 32,
      isAvailableNow: false,
    ),
    'v6': const VehicleDetails(
      id: 'v6',
      make: 'Force',
      model: 'Urbania',
      year: 2025,
      vehicleClass: 'Urbania / Van',
      seatingCapacity: 14,
      transmission: 'MANUAL',
      verificationStatus: 'VERIFIED',
      galleryUrls: ['assets/images/vehicles/urbania.jpg'],
      suitabilityInfo:
          'VIP guest transit with individual luxury reclining seats, individual AC blowers, and generous aisle space for festive family groups.',
      suitableCeremonies: ['Guest Transport', 'Airport VIP'],
      amenities: [
        'Individual Reclining Plush Seats',
        'Overhead Luggage Racks',
        'Dual High-Capacity AC',
        'Microphone & PA System for Family Announcements',
      ],
      ceremonialAddons: [],
      pricing: PricingSummary(basePriceCents: 1500000, billingUnit: 'DAY'),
      chauffeurId: 'd5',
      rating: 4.6,
      reviewCount: 88,
      isAvailableNow: true,
    ),
    'v7': const VehicleDetails(
      id: 'v7',
      make: 'Maruti',
      model: 'Ertiga',
      year: 2023,
      vehicleClass: 'Premium MPV',
      seatingCapacity: 6,
      transmission: 'MANUAL',
      verificationStatus: 'PENDING',
      galleryUrls: [],
      suitabilityInfo:
          'Cost-effective city shuttling for wedding staff and shopping errands.',
      suitableCeremonies: ['Guest Transport'],
      amenities: ['Air Conditioning'],
      ceremonialAddons: [],
      pricing: PricingSummary(basePriceCents: 800000, billingUnit: 'HOUR'),
      chauffeurId: 'd6',
      rating: 4.2,
      reviewCount: 150,
      isAvailableNow: true,
    ),
  };

  final List<VehicleSummary> _mockVehicles = [
    VehicleSummary(
      id: 'v1',
      make: 'BMW',
      model: '5 Series',
      year: 2025,
      vehicleClass: 'Luxury Sedan',
      registrationNumber: 'DL 01 SH 1234',
      seatingCapacity: 4,
      verificationStatus: 'VERIFIED',
      rating: 4.9,
      reviewCount: 128,
      hasVerifiedChauffeur: true,
      distanceKm: 2.5,
      transmission: 'AUTOMATIC',
      amenities: ['AC', 'WiFi', 'Water', 'Charger'],
      isAvailableNow: true,
      pricing: const PricingSummary(
        basePriceCents: 2500000,
        billingUnit: 'DAY',
      ),
    ),
    VehicleSummary(
      id: 'v2',
      make: 'Audi',
      model: 'A6',
      year: 2024,
      vehicleClass: 'Premium Sedan',
      registrationNumber: 'UP 16 BJ 5678',
      seatingCapacity: 4,
      verificationStatus: 'VERIFIED',
      rating: 4.8,
      reviewCount: 95,
      hasVerifiedChauffeur: true,
      distanceKm: 4.2,
      transmission: 'AUTOMATIC',
      amenities: ['AC', 'Water', 'Charger'],
      isAvailableNow: false,
      pricing: const PricingSummary(
        basePriceCents: 2200000,
        billingUnit: 'DAY',
      ),
    ),
    VehicleSummary(
      id: 'v3',
      make: 'Toyota',
      model: 'Fortuner',
      year: 2025,
      vehicleClass: 'Premium SUV',
      registrationNumber: 'HR 26 CK 9012',
      seatingCapacity: 7,
      verificationStatus: 'VERIFIED',
      rating: 4.7,
      reviewCount: 210,
      hasVerifiedChauffeur: true,
      distanceKm: 1.8,
      transmission: 'AUTOMATIC',
      amenities: ['AC', 'Water', 'WiFi'],
      isAvailableNow: true,
      pricing: const PricingSummary(
        basePriceCents: 1800000,
        billingUnit: 'DAY',
      ),
    ),
    VehicleSummary(
      id: 'v4',
      make: 'Mercedes-Benz',
      model: 'S-Class',
      year: 2026,
      vehicleClass: 'Luxury Sedan',
      registrationNumber: 'DL 02 SS 0001',
      seatingCapacity: 4,
      verificationStatus: 'VERIFIED',
      rating: 5.0,
      reviewCount: 45,
      hasVerifiedChauffeur: true,
      distanceKm: 5.5,
      transmission: 'AUTOMATIC',
      amenities: ['AC', 'WiFi', 'Water', 'Charger', 'Champagne Cooler'],
      isAvailableNow: true,
      pricing: const PricingSummary(
        basePriceCents: 5500000,
        billingUnit: 'DAY',
      ),
    ),
    VehicleSummary(
      id: 'v5',
      make: 'Vintage',
      model: 'Rolls Royce Silver Cloud',
      year: 1960,
      vehicleClass: 'Vintage',
      registrationNumber: 'VINT 001',
      seatingCapacity: 4,
      verificationStatus: 'VERIFIED',
      rating: 4.9,
      reviewCount: 32,
      hasVerifiedChauffeur: true,
      distanceKm: 8.0,
      transmission: 'MANUAL',
      amenities: ['AC', 'Luxury Upholstery'],
      isAvailableNow: false,
      pricing: const PricingSummary(
        basePriceCents: 8500000,
        billingUnit: 'PACKAGE',
      ),
    ),
    VehicleSummary(
      id: 'v6',
      make: 'Force',
      model: 'Urbania',
      year: 2025,
      vehicleClass: 'Urbania / Van',
      registrationNumber: 'MH 01 UR 9999',
      seatingCapacity: 14,
      verificationStatus: 'VERIFIED',
      rating: 4.6,
      reviewCount: 88,
      hasVerifiedChauffeur: true,
      distanceKm: 3.0,
      transmission: 'MANUAL',
      amenities: ['AC', 'WiFi', 'Pushback Seats'],
      isAvailableNow: true,
      pricing: const PricingSummary(
        basePriceCents: 1500000,
        billingUnit: 'DAY',
      ),
    ),
    VehicleSummary(
      id: 'v7',
      make: 'Maruti',
      model: 'Ertiga',
      year: 2023,
      vehicleClass: 'Premium MPV',
      registrationNumber: 'RJ 14 ET 1212',
      seatingCapacity: 6,
      verificationStatus: 'PENDING',
      rating: 4.2,
      reviewCount: 150,
      hasVerifiedChauffeur: false,
      distanceKm: 1.2,
      transmission: 'MANUAL',
      amenities: ['AC'],
      isAvailableNow: true,
      pricing: const PricingSummary(
        basePriceCents: 800000,
        billingUnit: 'HOUR',
      ),
    ),
  ];
}

class MockServiceCategoryRepository implements ServiceCategoryRepository {
  @override
  Future<Result<List<ServiceCategory>>> getCategories() async {
    return const Result.success([
      ServiceCategory(id: 'c1', name: 'Wedding Cars'),
      ServiceCategory(id: 'c2', name: 'Bride Entry'),
      ServiceCategory(id: 'c3', name: 'Groom Entry'),
      ServiceCategory(id: 'c4', name: 'Baraat'),
      ServiceCategory(id: 'c5', name: 'Vidai'),
      ServiceCategory(id: 'c6', name: 'Guest Transportation'),
      ServiceCategory(id: 'c7', name: 'Airport VIP'),
      ServiceCategory(id: 'c8', name: 'Pre-Wedding Shoot'),
    ]);
  }
}

class MockServiceAddonRepository implements ServiceAddonRepository {
  @override
  Future<Result<List<ServiceAddon>>> getAddons() async {
    return const Result.success([
      ServiceAddon(
        id: 'a1',
        name: 'Royal Baraat',
        description:
            'Complete processional coordination with vintage floral decor.',
        features: [
          'Vintage Decor',
          'Professional Coordinator',
          '4 Hour Service',
        ],
        pricing: PricingSummary(
          basePriceCents: 4500000,
          billingUnit: 'PACKAGE',
        ),
      ),
      ServiceAddon(
        id: 'a2',
        name: 'Bride Entry',
        description: 'Grand arrival experience with aesthetic floral themes.',
        features: ['Themed Decor', 'Cold Pyros', 'Luxury Chauffeur'],
        pricing: PricingSummary(
          basePriceCents: 3500000,
          billingUnit: 'PACKAGE',
        ),
      ),
    ]);
  }
}

class MockDriverRepository implements DriverRepository {
  @override
  Future<Result<DriverProfile>> getProfile() async {
    return Result.success(_mockDrivers['d1']!);
  }

  @override
  Future<Result<DriverProfile>> getDriverById(String driverId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final driver = _mockDrivers[driverId];
    if (driver != null) {
      return Result.success(driver);
    }
    return Result.failure(
      NotFoundFailure('Chauffeur profile not found for ID: $driverId'),
    );
  }

  @override
  Future<Result<DriverProfile>> updateDriverProfile(
    DriverProfile profile,
  ) async {
    await Future.delayed(const Duration(milliseconds: 150));
    _mockDrivers[profile.id] = profile;
    return Result.success(profile);
  }

  static void setMockDriver(String id, DriverProfile profile) {
    _mockDrivers[id] = profile;
  }

  static final Map<String, DriverDutyStatus> _dutyStatuses = {
    'd1': DriverDutyStatus.available,
    'd2': DriverDutyStatus.available,
    'd3': DriverDutyStatus.available,
    'd4': DriverDutyStatus.offline,
    'd5': DriverDutyStatus.busy,
    'd6': DriverDutyStatus.offline,
  };

  @override
  Future<Result<DriverDutyStatus>> getDutyStatus(String driverId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final status = _dutyStatuses[driverId] ?? DriverDutyStatus.available;
    return Result.success(status);
  }

  @override
  Future<Result<void>> updateDutyStatus({
    required String driverId,
    required DriverDutyStatus status,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _dutyStatuses[driverId] = status;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> updateOnlineStatus(bool isOnline) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return const Result.success(null);
  }

  @override
  Future<Result<void>> submitPreTripChecklist({
    required String bookingId,
    required bool isFuelChecked,
    required bool isDualAcChecked,
    required bool isGroomingChecked,
  }) async => const Result.success(null);

  @override
  Future<Result<void>> sendTelemetryPing({
    required double latitude,
    required double longitude,
    required double speedKmh,
    required double bearing,
  }) async => const Result.success(null);

  static final Map<String, DriverProfile> _mockDrivers = {
    'd1': DriverProfile(
      id: 'd1',
      fullName: 'Rajesh Kumar',
      verificationStatus: 'VERIFIED',
      isOnline: true,
      experienceYears: 12,
      weddingExperienceYears: 9,
      rating: 4.9,
      totalTrips: 450,
      operatingArea: 'Delhi NCR, Gurugram, Noida',
      identityVerified: true,
      bio:
          'Senior Ceremonial Chauffeur with 9 years of specialized wedding procession experience. Trained in Baraat pacing, slow maneuvering, and royal hospitality protocol. Familiar with formal Safa & Bandhgala dress codes.',
      languages: const ['Hindi', 'English', 'Punjabi'],
      recentReviews: [
        ReviewSummary(
          id: 'rev_1',
          reviewerName: 'Vikram Mehra',
          rating: 5.0,
          comment:
              'Impeccably punctual for our Baraat at The Oberoi. Handled the slow procession with incredible patience and composure.',
          createdAt: DateTime(2026, 8, 10),
        ),
        ReviewSummary(
          id: 'rev_2',
          reviewerName: 'Ananya Sharma',
          rating: 4.8,
          comment:
              'Very respectful and assisted my elderly grandparents with the utmost warmth. Truly royal service.',
          createdAt: DateTime(2026, 7, 28),
        ),
      ],
    ),
    'd2': DriverProfile(
      id: 'd2',
      fullName: 'Vikram Singh',
      verificationStatus: 'VERIFIED',
      isOnline: true,
      experienceYears: 8,
      weddingExperienceYears: 6,
      rating: 4.8,
      totalTrips: 310,
      operatingArea: 'Delhi NCR, Noida, Greater Noida',
      identityVerified: true,
      bio:
          'Expert chauffeur dedicated to VIP transfers and quiet, dignified Vidai departures. Punctual, soft-spoken, and expert in route planning.',
      languages: const ['Hindi', 'English'],
      recentReviews: [
        ReviewSummary(
          id: 'rev_3',
          reviewerName: 'Rohit Singhania',
          rating: 4.9,
          comment:
              'Arrived 45 minutes early without disturbing anyone and waited calmly for the Vidai muhurat.',
          createdAt: DateTime(2026, 8, 2),
        ),
      ],
    ),
    'd3': DriverProfile(
      id: 'd3',
      fullName: 'Harpreet Singh',
      verificationStatus: 'VERIFIED',
      isOnline: true,
      experienceYears: 10,
      weddingExperienceYears: 7,
      rating: 4.7,
      totalTrips: 280,
      operatingArea: 'Delhi NCR, Gurugram, Jaipur',
      identityVerified: true,
      bio:
          'Luxury SUV logistics specialist. Expert in coordinating multi-vehicle guest convoys and farmhouse destination transfers.',
      languages: const ['Hindi', 'Punjabi'],
      recentReviews: [
        ReviewSummary(
          id: 'rev_4',
          reviewerName: 'Kavita Chawla',
          rating: 4.7,
          comment:
              'Handled our outstation guest transfer from Delhi to Jaipur seamlessly.',
          createdAt: DateTime(2026, 6, 15),
        ),
      ],
    ),
    'd4': DriverProfile(
      id: 'd4',
      fullName: 'Gajendra Rathore',
      verificationStatus: 'VERIFIED',
      isOnline: false,
      experienceYears: 15,
      weddingExperienceYears: 14,
      rating: 4.95,
      totalTrips: 520,
      operatingArea: 'Delhi NCR, Jaipur, Udaipur',
      identityVerified: true,
      bio:
          'Master of vintage and heritage ceremonial mobility. Over 14 years driving royal entries across palace banquets and luxury heritage hotels.',
      languages: const ['Hindi', 'English', 'Rajasthani'],
      recentReviews: [
        ReviewSummary(
          id: 'rev_5',
          reviewerName: 'Yuvraj Solanki',
          rating: 5.0,
          comment:
              'The vintage Rolls Royce entry was majestic. Gajendra ji looked regal in full traditional bandhgala attire.',
          createdAt: DateTime(2026, 8, 22),
        ),
      ],
    ),
    'd5': DriverProfile(
      id: 'd5',
      fullName: 'Manoj Verma',
      verificationStatus: 'VERIFIED',
      isOnline: true,
      experienceYears: 7,
      weddingExperienceYears: 5,
      rating: 4.6,
      totalTrips: 190,
      operatingArea: 'Delhi NCR, Faridabad',
      identityVerified: true,
      bio:
          'Specialist in large-capacity VIP vans and urban transport coordination for extended family wedding groups.',
      languages: const ['Hindi'],
      recentReviews: [],
    ),
    'd6': DriverProfile(
      id: 'd6',
      fullName: 'Suresh Yadav',
      verificationStatus: 'PENDING',
      isOnline: true,
      experienceYears: 4,
      weddingExperienceYears: 1,
      rating: 4.2,
      totalTrips: 85,
      operatingArea: 'Delhi NCR',
      identityVerified: false,
      bio: 'Commercial driver onboarding for seasonal wedding shuttles.',
      languages: const ['Hindi'],
      recentReviews: [],
    ),
  };
}
