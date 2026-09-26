/// Server-authoritative booking lifecycle states matching BOOKING_STATE_MACHINE.md.
///
/// NOTE: The mobile client NEVER invents or forces booking states.
/// All states are determined and returned authoritatively by the backend.
enum BookingStatus {
  /// Customer has submitted the booking intent. ShadiDriver operations now owns it.
  requested,

  /// Operations is sourcing vehicles for the request.
  underReview,

  /// Operations reserved vehicles and committed chauffeurs internally.
  vehicleOptionsPrepared,

  /// Operations has contacted the customer and awaits their agreement.
  customerConfirmationPending,

  /// Legacy marketplace state — kept only so old payloads still parse.
  /// Presented neutrally: the customer waits on ShadiDriver, not on a driver
  /// accepting their job.
  driverAccepted,

  /// Driver or fleet declined or was unavailable.
  rejected,

  /// Acceptance window expired without driver acceptance.
  expired,

  /// Advance token invoice created; waiting for payment completion.
  paymentPending,

  /// Advance token verified; booking secured.
  confirmed,

  /// Payment gateway error during token authorization.
  paymentFailed,

  /// Cancelled by customer or admin under applicable policy.
  cancelled,

  /// Chauffeur verified, allocated, and briefed.
  driverAssigned,

  /// Chauffeur is in transit to the pickup/ceremony venue.
  driverArriving,

  /// Chauffeur has arrived at venue gate.
  arrived,

  /// Ceremony procession or journey has begun.
  tripStarted,

  /// Ceremony concluded and signed off.
  completed,

  /// Emergency standby chauffeur dispatched.
  emergencyReplacement;

  /// User-facing status label for client UI display.
  String get displayLabel {
    switch (this) {
      case BookingStatus.requested:
        return 'Request Submitted';
      case BookingStatus.underReview:
        return 'Under Review';
      case BookingStatus.vehicleOptionsPrepared:
        return 'Vehicles Reserved';
      case BookingStatus.customerConfirmationPending:
        return 'Awaiting Your Confirmation';
      case BookingStatus.driverAccepted:
        return 'Being Prepared';
      case BookingStatus.rejected:
        return 'Booking Declined';
      case BookingStatus.expired:
        return 'Request Expired';
      case BookingStatus.paymentPending:
        return 'Payment Pending';
      case BookingStatus.confirmed:
        return 'Booking Confirmed';
      case BookingStatus.paymentFailed:
        return 'Payment Failed';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.driverAssigned:
        return 'Chauffeur Assigned';
      case BookingStatus.driverArriving:
        return 'Chauffeur En Route';
      case BookingStatus.arrived:
        return 'Chauffeur Arrived';
      case BookingStatus.tripStarted:
        return 'Ceremony in Progress';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.emergencyReplacement:
        return 'Standby Chauffeur Dispatched';
    }
  }

  /// Informational subtitle explaining current state to the customer.
  String get customerSubtitle {
    switch (this) {
      case BookingStatus.requested:
        return 'ShadiDriver is reviewing your request and preparing your fleet.';
      case BookingStatus.underReview:
        return 'Operations is allocating vehicles and chauffeurs for your dates.';
      case BookingStatus.vehicleOptionsPrepared:
        return 'Your vehicles and chauffeurs are reserved. We will contact you to confirm.';
      case BookingStatus.customerConfirmationPending:
        return 'ShadiDriver has shared your final fleet and price — confirm to lock it in.';
      case BookingStatus.driverAccepted:
        return 'ShadiDriver is preparing your fleet and chauffeur.';
      case BookingStatus.paymentPending:
        return 'Please complete advance token deposit to lock reservation.';
      case BookingStatus.confirmed:
        return 'Ceremony reservation officially secured.';
      default:
        return '';
    }
  }
}
