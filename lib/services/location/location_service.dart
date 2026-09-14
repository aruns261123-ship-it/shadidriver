/// Hardware/OS abstraction for GPS geolocation.
abstract interface class LocationService {
  Future<bool> isLocationServiceEnabled();
  Future<bool> requestLocationPermission();
  Future<Map<String, double>?> getCurrentPosition();
  Stream<Map<String, double>> get positionStream;
}
