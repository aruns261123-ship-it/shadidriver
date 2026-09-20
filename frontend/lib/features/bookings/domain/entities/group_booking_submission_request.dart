import 'package:flutter/foundation.dart';
import 'customer_fleet_intent.dart';

/// Customer submission request for creating a multi-vehicle / group booking.
@immutable
class GroupBookingSubmissionRequest {
  final CustomerFleetIntent fleetIntent;
  final String ceremonyType;
  final DateTime serviceStartDateTime;
  final DateTime serviceEndDateTime;
  final String city;
  final String pickupAddress;
  final String destinationAddress;
  final String primaryContactName;
  final String primaryContactPhone;
  final String idempotencyKey;

  const GroupBookingSubmissionRequest({
    required this.fleetIntent,
    required this.ceremonyType,
    required this.serviceStartDateTime,
    required this.serviceEndDateTime,
    required this.city,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.primaryContactName,
    required this.primaryContactPhone,
    required this.idempotencyKey,
  });
}
