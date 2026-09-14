import '../../../../core/result/result.dart';
import '../../vehicles/domain/entities/pricing_summary.dart';
import '../../vehicles/domain/entities/vehicle_summary.dart';
import '../../vehicles/domain/repositories/vehicle_repository.dart';
import '../../services/domain/entities/service_category.dart';
import '../../services/domain/entities/service_addon.dart';
import '../../services/domain/repositories/service_category_repository.dart';
import '../../services/domain/repositories/service_addon_repository.dart';
import '../../drivers/domain/entities/driver_profile.dart';
import '../../drivers/domain/repositories/driver_repository.dart';

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
    final vehicle = _mockVehicles.firstWhere((v) => v.id == vehicleId);
    return Result.success(vehicle);
  }

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
      pricing: const PricingSummary(
        basePriceCents: 2500000, // 25,000 INR
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
      pricing: const PricingSummary(
        basePriceCents: 2200000, // 22,000 INR
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
      pricing: const PricingSummary(
        basePriceCents: 1800000, // 18,000 INR
        billingUnit: 'DAY',
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
    return const Result.success(
      DriverProfile(
        id: 'd1',
        fullName: 'Rajesh Kumar',
        verificationStatus: 'VERIFIED',
        isOnline: true,
        experienceYears: 12,
        rating: 4.9,
        totalTrips: 450,
      ),
    );
  }

  @override
  Future<Result<void>> updateOnlineStatus(bool isOnline) async =>
      const Result.success(null);

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
}
