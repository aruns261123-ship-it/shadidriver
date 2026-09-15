import 'package:flutter/foundation.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../bookings/domain/entities/booking_status.dart';
import '../../../bookings/domain/entities/booking_submission_result.dart';
import '../../../bookings/domain/policies/booking_pricing_policy.dart';

/// Privacy-safe domain view of a ceremonial booking offer presented to a chauffeur.
///
/// In strict accordance with DPDP Act and ShadiDriver Security Architecture:
/// - Chauffeurs only see necessary ceremonial and logistical data prior to acceptance.
/// - Customer private phone numbers and personal details are strictly masked.
/// - Chauffeur earnings are derived from the server/pricing policy abstraction.
@immutable
class DriverBookingOffer {
  final String bookingId;
  final String bookingReference;
  final BookingStatus status;

  // Ceremonial & Service Details
  final String ceremonyType;
  final String ceremonialAttire;
  final DateTime eventDate;
  final int durationHours;

  // Route & Venues
  final String pickupAddress;
  final String destinationAddress;

  // Vehicle & Chauffeur Requirement
  final String vehicleName;
  final String vehicleClass;
  final int passengerCount;
  final String? specialInstructions;

  // Privacy-Preserved Contact Information
  final String maskedContactName;
  final String maskedContactPhone;

  // Financials
  final int estimatedTotalPaise;
  final int estimatedDriverEarningsPaise;

  const DriverBookingOffer({
    required this.bookingId,
    required this.bookingReference,
    required this.status,
    required this.ceremonyType,
    required this.ceremonialAttire,
    required this.eventDate,
    required this.durationHours,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.vehicleName,
    required this.vehicleClass,
    this.passengerCount = 2,
    this.specialInstructions,
    required this.maskedContactName,
    required this.maskedContactPhone,
    required this.estimatedTotalPaise,
    required this.estimatedDriverEarningsPaise,
  });

  DateTime get startDateTime => eventDate;
  String get dropoffAddress => destinationAddress;
  String get maskedCustomerName => maskedContactName;
  String get maskedCustomerPhone => maskedContactPhone;
  String get eventName => '$ceremonyType ($vehicleName)';
  String get pickupCity {
    final parts = pickupAddress.split(',');
    return parts.length > 1 ? parts.last.trim() : pickupAddress;
  }

  String get formattedDriverEarningsPaise =>
      CurrencyFormatter.formatPaise(estimatedDriverEarningsPaise);

  /// Factory constructing privacy-safe chauffeur offer from the shared [BookingSubmissionResult].
  factory DriverBookingOffer.fromBookingSubmissionResult(
    BookingSubmissionResult result,
    BookingPricingPolicy pricingPolicy, {
    int passengerCount = 2,
  }) {
    final earnings = pricingPolicy.calculateDriverEarningsPaise(
      result.estimatedTotalPaise,
    );

    return DriverBookingOffer(
      bookingId: result.bookingId,
      bookingReference: result.bookingReference,
      status: result.status,
      ceremonyType: result.ceremonyType,
      ceremonialAttire: result.ceremonialAttire,
      eventDate: result.eventDate,
      durationHours: result.durationHours,
      pickupAddress: result.pickupAddress,
      destinationAddress: result.destinationAddress,
      vehicleName: result.vehicleName,
      vehicleClass: result.vehicleClass,
      passengerCount: passengerCount,
      maskedContactName: _maskName(result.primaryContactName),
      maskedContactPhone: _maskPhone(result.primaryContactPhone),
      estimatedTotalPaise: result.estimatedTotalPaise,
      estimatedDriverEarningsPaise: earnings,
    );
  }

  /// Masks customer name to show ceremonial role and initial only (e.g. "Host: Vikram M.").
  static String _maskName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'Host';
    if (parts.length == 1) return 'Host: ${parts.first}';
    return 'Host: ${parts.first} ${parts[1][0].toUpperCase()}.';
  }

  /// Masks phone number per DPDP rules prior to acceptance (e.g. "+91 ••••• ••345").
  static String _maskPhone(String phone) {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length >= 4) {
      final last3 = clean.substring(clean.length - 3);
      return '+91 ••••• ••$last3';
    }
    return '+91 ••••• •••••';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriverBookingOffer &&
          other.bookingId == bookingId &&
          other.bookingReference == bookingReference &&
          other.status == status &&
          other.estimatedDriverEarningsPaise == estimatedDriverEarningsPaise);

  @override
  int get hashCode => Object.hash(
    bookingId,
    bookingReference,
    status,
    estimatedDriverEarningsPaise,
  );
}
