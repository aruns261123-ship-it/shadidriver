import 'package:flutter/foundation.dart';
import '../../../bookings/domain/entities/booking_status.dart';
import '../../../bookings/domain/entities/booking_submission_result.dart';
import 'driver_trip_stage.dart';

/// Immutable domain model representing a chauffeur's active ceremonial trip assignment.
@immutable
class DriverActiveTrip {
  final String bookingId;
  final String bookingReference;
  final String ceremonyType;
  final String ceremonialAttire;
  final DriverTripStage stage;
  final String pickupAddress;
  final String destinationAddress;
  final String venueName;
  final String landmark;
  final String primaryContactName;
  final String primaryContactPhone;
  final DateTime serviceStartDateTime;
  final DateTime serviceEndDateTime;
  final double? routeDistanceKm;
  final String vehicleName;

  /// Estimated booking total in paise — drives the chauffeur earnings summary.
  final int? estimatedTotalPaise;
  final String startOtp;
  final DateTime? tripStartedAt;
  final DateTime? tripCompletedAt;
  final bool ceremonialAttireConfirmed;

  const DriverActiveTrip({
    required this.bookingId,
    required this.bookingReference,
    required this.ceremonyType,
    required this.ceremonialAttire,
    required this.stage,
    required this.pickupAddress,
    required this.destinationAddress,
    this.venueName = '',
    this.landmark = '',
    required this.primaryContactName,
    required this.primaryContactPhone,
    required this.serviceStartDateTime,
    required this.serviceEndDateTime,
    this.routeDistanceKm,
    required this.vehicleName,
    this.estimatedTotalPaise,
    this.startOtp = '1234',
    this.tripStartedAt,
    this.tripCompletedAt,
    this.ceremonialAttireConfirmed = false,
  });

  int get durationHours =>
      serviceEndDateTime.difference(serviceStartDateTime).inHours;

  DriverActiveTrip copyWith({
    DriverTripStage? stage,
    DateTime? tripStartedAt,
    DateTime? tripCompletedAt,
    bool? ceremonialAttireConfirmed,
  }) {
    return DriverActiveTrip(
      bookingId: bookingId,
      bookingReference: bookingReference,
      ceremonyType: ceremonyType,
      ceremonialAttire: ceremonialAttire,
      stage: stage ?? this.stage,
      pickupAddress: pickupAddress,
      destinationAddress: destinationAddress,
      venueName: venueName,
      landmark: landmark,
      primaryContactName: primaryContactName,
      primaryContactPhone: primaryContactPhone,
      serviceStartDateTime: serviceStartDateTime,
      serviceEndDateTime: serviceEndDateTime,
      routeDistanceKm: routeDistanceKm,
      vehicleName: vehicleName,
      estimatedTotalPaise: estimatedTotalPaise,
      startOtp: startOtp,
      tripStartedAt: tripStartedAt ?? this.tripStartedAt,
      tripCompletedAt: tripCompletedAt ?? this.tripCompletedAt,
      ceremonialAttireConfirmed:
          ceremonialAttireConfirmed ?? this.ceremonialAttireConfirmed,
    );
  }

  /// Factory building a chauffeur trip view from the shared booking record.
  ///
  /// [stage] overrides the derived lifecycle stage; when omitted, the stage is
  /// resolved from the server-authoritative booking status.
  factory DriverActiveTrip.fromBookingResult(
    BookingSubmissionResult result, {
    DriverTripStage? stage,
  }) {
    final resolvedStage =
        stage ??
        switch (result.status) {
          BookingStatus.completed => DriverTripStage.completed,
          BookingStatus.tripStarted => DriverTripStage.ceremonyInProgress,
          BookingStatus.arrived => DriverTripStage.arrivedAtPickup,
          BookingStatus.driverArriving => DriverTripStage.enRouteToPickup,
          _ => DriverTripStage.assigned,
        };

    return DriverActiveTrip(
      bookingId: result.bookingId,
      bookingReference: result.bookingReference,
      ceremonyType: result.ceremonyType,
      ceremonialAttire: result.ceremonialAttire,
      stage: resolvedStage,
      pickupAddress: result.pickupAddress,
      destinationAddress: result.destinationAddress,
      primaryContactName: result.primaryContactName,
      primaryContactPhone: result.primaryContactPhone,
      serviceStartDateTime: result.serviceStartDateTime,
      serviceEndDateTime: result.serviceEndDateTime,
      routeDistanceKm: result.routeDistanceKm,
      vehicleName: result.vehicleName,
      estimatedTotalPaise: result.estimatedTotalPaise,
    );
  }

  /// Initial seeded trip instance for development and tests
  factory DriverActiveTrip.mockInitial({String bookingId = 'bk_mock_req_1'}) {
    return DriverActiveTrip(
      bookingId: bookingId,
      bookingReference: 'SD-2026-0100',
      ceremonyType: 'Baraat',
      ceremonialAttire: 'Royal Bandhgala & Gold Safa',
      stage: DriverTripStage.assigned,
      pickupAddress: 'The Oberoi Hotel, New Delhi',
      destinationAddress: 'Grand Imperial Banquets, MG Road',
      venueName: 'Grand Imperial Ballroom',
      landmark: 'Gate 2 VIP Entrance',
      primaryContactName: 'Vikram Malhotra',
      primaryContactPhone: '+91 98100 12345',
      serviceStartDateTime: DateTime(2026, 11, 20, 16, 0),
      serviceEndDateTime: DateTime(2026, 11, 21, 0, 0),
      routeDistanceKm: 24.5,
      vehicleName: 'BMW 5 Series',
      startOtp: '1234',
    );
  }
}
