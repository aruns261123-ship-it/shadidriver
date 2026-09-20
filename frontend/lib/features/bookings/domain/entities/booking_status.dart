/// Server-authoritative booking lifecycle states matching BOOKING_STATE_MACHINE.md.
///
/// NOTE: The mobile client NEVER invents or forces booking states.
/// All states are determined and returned authoritatively by the backend.
enum BookingStatus {
  /// Customer has submitted the booking intent. Chauffeur/fleet confirmation pending.
  requested,

  /// Driver/Fleet has accepted the booking request.
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
      case BookingStatus.driverAccepted:
        return 'Driver Accepted';
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
        return 'Awaiting chauffeur confirmation and schedule lock.';
      case BookingStatus.driverAccepted:
        return 'Chauffeur accepted. Preparing advance token order.';
      case BookingStatus.paymentPending:
        return 'Please complete advance token deposit to lock reservation.';
      case BookingStatus.confirmed:
        return 'Ceremony reservation officially secured.';
      default:
        return '';
    }
  }
}
