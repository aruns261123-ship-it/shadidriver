import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/home/presentation/view_models/vehicle_card_view_model.dart';
import 'package:shadidriver/features/vehicles/domain/entities/pricing_summary.dart';
import 'package:shadidriver/features/vehicles/domain/entities/vehicle_summary.dart';

void main() {
  test('VehicleCardViewModel.fromEntity maps domain data correctly', () {
    const vehicle = VehicleSummary(
      id: 'v1',
      make: 'Mercedes',
      model: 'S-Class',
      year: 2025,
      vehicleClass: 'Ultra Luxury',
      registrationNumber: 'DL 01',
      seatingCapacity: 4,
      verificationStatus: 'VERIFIED',
      rating: 5.0,
      reviewCount: 50,
      hasVerifiedChauffeur: true,
      pricing: PricingSummary(basePriceCents: 5000000, billingUnit: 'DAY'),
    );

    final viewModel = VehicleCardViewModel.fromEntity(vehicle);

    expect(viewModel.title, equals('Mercedes S-Class'));
    expect(viewModel.ratingText, equals('5.0'));
    expect(viewModel.priceUnit, equals('/ day'));
    expect(viewModel.isVerifiedVehicle, isTrue);
  });
}
