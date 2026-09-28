import 'package:flutter/foundation.dart';

/// One vehicle-type line of the guest's temporary fleet selection.
@immutable
class GuestFleetLine {
  final String vehicleTypeId;
  final String displayName;
  final String vehicleClass;
  final int seatingCapacity;
  final int quantity;

  const GuestFleetLine({
    required this.vehicleTypeId,
    required this.displayName,
    required this.vehicleClass,
    required this.seatingCapacity,
    required this.quantity,
  });

  GuestFleetLine copyWith({int? quantity}) => GuestFleetLine(
        vehicleTypeId: vehicleTypeId,
        displayName: displayName,
        vehicleClass: vehicleClass,
        seatingCapacity: seatingCapacity,
        quantity: quantity ?? this.quantity,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GuestFleetLine &&
          other.vehicleTypeId == vehicleTypeId &&
          other.quantity == quantity);

  @override
  int get hashCode => Object.hash(vehicleTypeId, quantity);
}

/// Trip context captured alongside the guest's vehicle selection so the
/// WHOLE booking intent — not just the cars — survives authentication.
@immutable
class GuestTripDetails {
  final String? ceremonyType;
  final String? city;
  final String? pickupAddress;
  final String? destinationAddress;
  final DateTime? serviceStart;
  final DateTime? serviceEnd;
  final int? passengerCount;
  final String? contactName;
  final String? contactPhone;

  const GuestTripDetails({
    this.ceremonyType,
    this.city,
    this.pickupAddress,
    this.destinationAddress,
    this.serviceStart,
    this.serviceEnd,
    this.passengerCount,
    this.contactName,
    this.contactPhone,
  });

  /// True when at least one trip field carries intent worth restoring.
  bool get hasAny =>
      (ceremonyType != null && ceremonyType!.isNotEmpty) ||
      (pickupAddress != null && pickupAddress!.trim().isNotEmpty) ||
      (destinationAddress != null && destinationAddress!.trim().isNotEmpty) ||
      serviceStart != null ||
      (passengerCount != null && passengerCount! > 0);

  GuestTripDetails copyWith({
    String? ceremonyType,
    String? city,
    String? pickupAddress,
    String? destinationAddress,
    DateTime? serviceStart,
    DateTime? serviceEnd,
    int? passengerCount,
    String? contactName,
    String? contactPhone,
  }) =>
      GuestTripDetails(
        ceremonyType: ceremonyType ?? this.ceremonyType,
        city: city ?? this.city,
        pickupAddress: pickupAddress ?? this.pickupAddress,
        destinationAddress: destinationAddress ?? this.destinationAddress,
        serviceStart: serviceStart ?? this.serviceStart,
        serviceEnd: serviceEnd ?? this.serviceEnd,
        passengerCount: passengerCount ?? this.passengerCount,
        contactName: contactName ?? this.contactName,
        contactPhone: contactPhone ?? this.contactPhone,
      );
}

/// The signed-out visitor's booking selection.
///
/// An app-level, session-scoped model — deliberately NOT widget-local state —
/// so the selection outlives the screen that produced it and can be restored
/// after the guest authenticates mid-flow. Cleared when the booking it feeds
/// is submitted (or when the customer signs out on this device).
@immutable
class GuestFleetSelection {
  final List<GuestFleetLine> lines;
  final GuestTripDetails trip;

  const GuestFleetSelection({
    this.lines = const [],
    this.trip = const GuestTripDetails(),
  });

  bool get isEmpty => lines.isEmpty;
  bool get isNotEmpty => lines.isNotEmpty;

  /// Total number of vehicles across all lines (e.g. "3 Cars Selected").
  int get totalVehicles =>
      lines.fold(0, (sum, l) => sum + l.quantity);

  int get totalCapacity =>
      lines.fold(0, (sum, l) => sum + l.quantity * l.seatingCapacity);

  bool containsType(String vehicleTypeId) =>
      lines.any((l) => l.vehicleTypeId == vehicleTypeId);

  /// The line for [vehicleTypeId], or null when this vehicle type is not part
  /// of the selection. The ONE lookup every surface derives its selected state
  /// from — no screen keeps its own `bool isSelected`.
  GuestFleetLine? lineForType(String vehicleTypeId) {
    for (final l in lines) {
      if (l.vehicleTypeId == vehicleTypeId) return l;
    }
    return null;
  }

  /// Selected units of [vehicleTypeId] (0 when absent).
  int quantityOf(String vehicleTypeId) => lineForType(vehicleTypeId)?.quantity ?? 0;

  GuestFleetSelection upsertType({
    required String vehicleTypeId,
    required String displayName,
    required String vehicleClass,
    required int seatingCapacity,
    required int quantityDelta,
  }) {
    final existing = lines
        .where((l) => l.vehicleTypeId == vehicleTypeId)
        .toList(growable: false);
    final List<GuestFleetLine> updated;
    if (existing.isEmpty) {
      if (quantityDelta <= 0) return this;
      updated = [
        ...lines,
        GuestFleetLine(
          vehicleTypeId: vehicleTypeId,
          displayName: displayName,
          vehicleClass: vehicleClass,
          seatingCapacity: seatingCapacity,
          quantity: quantityDelta,
        ),
      ];
    } else {
      final current = existing.first;
      final next = current.quantity + quantityDelta;
      updated = next <= 0
          ? lines.where((l) => l.vehicleTypeId != vehicleTypeId).toList()
          : [
              for (final l in lines)
                if (l.vehicleTypeId == vehicleTypeId)
                  l.copyWith(quantity: next)
                else
                  l,
            ];
    }
    return GuestFleetSelection(lines: updated, trip: trip);
  }

  GuestFleetSelection withQuantity(String vehicleTypeId, int quantity) {
    if (quantity <= 0) {
      return GuestFleetSelection(
        lines:
            lines.where((l) => l.vehicleTypeId != vehicleTypeId).toList(),
        trip: trip,
      );
    }
    return GuestFleetSelection(
      lines: [
        for (final l in lines)
          if (l.vehicleTypeId == vehicleTypeId)
            l.copyWith(quantity: quantity)
          else
            l,
      ],
      trip: trip,
    );
  }

  GuestFleetSelection withTrip(GuestTripDetails trip) =>
      GuestFleetSelection(lines: lines, trip: trip);

  GuestFleetSelection clear() => const GuestFleetSelection();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GuestFleetSelection &&
          listEquals(other.lines, lines) &&
          other.trip == trip);

  @override
  int get hashCode => Object.hash(Object.hashAll(lines), trip);
}
