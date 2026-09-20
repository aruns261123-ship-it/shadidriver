import '../domain/services/route_distance_service.dart';

/// Deterministic mock implementation of [RouteDistanceService] for development.
///
/// Produces consistent distance estimates without calling external Mapbox/Google APIs.
class MockRouteDistanceService implements RouteDistanceService {
  const MockRouteDistanceService();

  @override
  Future<double> estimateDistanceKm({
    required String pickupAddress,
    required String destinationAddress,
    required String city,
  }) async {
    // Simulate brief calculation delay
    await Future.delayed(const Duration(milliseconds: 80));

    final pickup = pickupAddress.trim().toLowerCase();
    final dest = destinationAddress.trim().toLowerCase();

    // Known ceremonial corridor distances in Delhi NCR
    if (pickup.contains('oberoi') && dest.contains('grand imperial')) {
      return 24.5;
    }
    if ((pickup.contains('delhi') || pickup.contains('connaught')) &&
        dest.contains('noida')) {
      return 28.0;
    }
    if (pickup.contains('aerocity') && dest.contains('cyber hub')) {
      return 14.8;
    }
    if (pickup.contains('chanakyapuri') && dest.contains('chattarpur')) {
      return 18.2;
    }
    if (pickup.contains('taj') && dest.contains('farms')) {
      return 22.0;
    }

    // Deterministic fallback based on input hash (range: 8.5 km to 36.5 km)
    final hashSum =
        (pickup.hashCode.abs() + dest.hashCode.abs() + city.hashCode.abs());
    final pseudoKm = 8.5 + (hashSum % 280) / 10.0;
    return double.parse(pseudoKm.toStringAsFixed(1));
  }
}
