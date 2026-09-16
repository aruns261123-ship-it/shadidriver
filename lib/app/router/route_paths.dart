/// Centralized type-safe route paths for ShadiDriver.
abstract final class RoutePaths {
  static const String splash = '/splash';
  static const String auth = '/auth';

  // Customer Portal
  static const String customer = '/customer';
  static const String customerHome = '/customer/home';
  static const String customerSearch = '/customer/search';
  static const String customerBookings = '/customer/bookings';
  static const String customerMessages = '/customer/messages';
  static const String customerProfile = '/customer/profile';
  static const String customerSearchResults = '/customer/search/results';
  static const String customerVehicleDetails = '/customer/vehicles/:vehicleId';
  static const String customerChauffeurProfile =
      '/customer/chauffeurs/:chauffeurId';
  static const String customerBookingCreate =
      '/customer/bookings/create/:vehicleId';
  static const String customerBookingReview =
      '/customer/bookings/review/:draftId';
  static const String customerBookingResult =
      '/customer/bookings/result/:bookingId';

  static String customerVehicleDetailsPath(String vehicleId) =>
      '/customer/vehicles/$vehicleId';
  static String customerChauffeurProfilePath(String chauffeurId) =>
      '/customer/chauffeurs/$chauffeurId';
  static String customerBookingCreatePath(String vehicleId) =>
      '/customer/bookings/create/$vehicleId';
  static String customerBookingReviewPath(String draftId) =>
      '/customer/bookings/review/$draftId';
  static String customerBookingResultPath(String bookingId) =>
      '/customer/bookings/result/$bookingId';

  // Customer Profile & Addresses
  static const String customerProfileEdit = '/customer/profile/edit';
  static const String customerAddresses = '/customer/addresses';

  // Driver Portal
  static const String driver = '/driver';
  static const String driverProfile = '/driver/profile';
  static const String driverProfileEdit = '/driver/profile/edit';
  static const String driverRequestDetails = '/driver/requests/:bookingId';
  static const String driverActiveTrip = '/driver/active-trip/:bookingId';

  static String driverRequestDetailsPath(String bookingId) =>
      '/driver/requests/$bookingId';
  static String driverActiveTripPath(String bookingId) =>
      '/driver/active-trip/$bookingId';

  // Admin Portal
  static const String admin = '/admin';
  static const String adminProfile = '/admin/profile';
}
