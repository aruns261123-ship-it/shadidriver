/// Pure Dart domain abstraction for route distance estimation.
///
/// Decouples the client booking flow from any specific vendor (Google Maps,
/// Mapbox, OSRM). The client uses deterministic development estimates;
/// the production backend calculates authoritative routing and road distance.
abstract interface class RouteDistanceService {
  /// Estimates travel distance in kilometers between [pickupAddress] and [destinationAddress]
  /// within or across [city].
  Future<double> estimateDistanceKm({
    required String pickupAddress,
    required String destinationAddress,
    required String city,
  });
}
