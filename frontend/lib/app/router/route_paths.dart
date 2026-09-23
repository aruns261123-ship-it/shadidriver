/// Centralized type-safe route paths for ShadiDriver.
abstract final class RoutePaths {
  static const String splash = '/splash';
  static const String auth = '/auth';
  static const String accountSuspended = '/account-suspended';

  // Customer Portal
  static const String customer = '/customer';
  static const String customerHome = '/customer/home';
  static const String customerSearch = '/customer/search';
  static const String customerBookings = '/customer/bookings';
  static const String customerMessages = '/customer/messages';
  static const String customerProfile = '/customer/profile';
  static const String customerNotifications = '/customer/notifications';
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
  static const String customerPaymentCheckout =
      '/customer/bookings/payment/:bookingId';
  static const String customerBookingDetail =
      '/customer/bookings/detail/:bookingId';
  static const String customerUrgentDispatch = '/customer/urgent-dispatch';
  static const String customerSupportTicket = '/customer/support';

  // Group / multi-vehicle booking
  static const String customerGroupBooking = '/customer/group-booking';
  static const String customerGroupBookingDetail =
      '/customer/group-booking/:groupBookingId';
  static String customerGroupBookingDetailPath(String groupBookingId) =>
      '/customer/group-booking/$groupBookingId';

  static String customerPaymentCheckoutPath(String bookingId) =>
      '/customer/bookings/payment/$bookingId';
  static String customerBookingDetailPath(String bookingId) =>
      '/customer/bookings/detail/$bookingId';

  static String customerVehicleDetailsPath(String vehicleId) =>
      '/customer/vehicles/$vehicleId';
  static String customerChauffeurProfilePath(String chauffeurId) =>
      '/customer/chauffeurs/$chauffeurId';
  static String customerBookingCreatePath(String vehicleId, {String? draftId}) {
    if (draftId != null && draftId.isNotEmpty) {
      return '/customer/bookings/create/$vehicleId?draftId=$draftId';
    }
    return '/customer/bookings/create/$vehicleId';
  }

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
