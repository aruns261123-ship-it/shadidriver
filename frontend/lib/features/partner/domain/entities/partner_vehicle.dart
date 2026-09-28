import 'partner_enums.dart';

/// One vehicle document as the partner sees it (`viewVehicle.documents[]`).
class PartnerVehicleDocument {
  final String type;
  final PartnerVerificationStatus status;
  final DateTime? expiresAt;

  const PartnerVehicleDocument({
    required this.type,
    required this.status,
    required this.expiresAt,
  });
}

/// A fleet vehicle — exactly `PartnerService.viewVehicle` (snake_case wire).
class PartnerVehicle {
  final String id;
  final String fleetCode;
  final String vehicleTypeId;
  final String? displayName;
  final int? seatingCapacity;
  final String? vehicleClass;
  final int year;
  final String registrationNumber;
  final String color;
  final String fuelType;
  final String transmission;
  final String city;
  final List<String> serviceAreas;
  final List<String> amenities;
  final List<String> photoUrls;
  final PartnerVerificationStatus verificationStatus;
  final bool isActive;
  final bool isAvailable;
  final bool isBookable;
  final List<PartnerVehicleDocument> documents;

  const PartnerVehicle({
    required this.id,
    required this.fleetCode,
    required this.vehicleTypeId,
    required this.displayName,
    required this.seatingCapacity,
    required this.vehicleClass,
    required this.year,
    required this.registrationNumber,
    required this.color,
    required this.fuelType,
    required this.transmission,
    required this.city,
    required this.serviceAreas,
    required this.amenities,
    required this.photoUrls,
    required this.verificationStatus,
    required this.isActive,
    required this.isAvailable,
    required this.isBookable,
    required this.documents,
  });

  /// Privacy-safe display identifier: shows only the last 4 of the plate.
  /// The partner owns the vehicle, but a shared showroom screen should not
  /// flash full plates in cafés.
  String get maskedRegistration {
    final plate = registrationNumber.trim();
    if (plate.length <= 4) return plate;
    return '•••• ${plate.substring(plate.length - 4)}';
  }

  bool get hasPendingDocuments => documents.any(
        (d) =>
            d.status == PartnerVerificationStatus.pendingSubmission ||
            d.status == PartnerVerificationStatus.underReview,
      );
}

/// One submitted tariff version (`PricingService.viewVersion`).
class VehicleTariff {
  final String id;
  final int version;
  final String currency;

  // amounts in paise (string on the wire — BigInt-safe)
  final int? localIncludedKm;
  final String? localAmountPaise;
  final String? perKmPaise;
  final String? hourlyPaise;
  final String? extraHourPaise;
  final String? fullDayPaise;
  final String? overnightPaise;
  final String? outstationPerDayPaise;
  final String? outstationPerKmPaise;

  final TariffStatus status;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? decisionReason;
  final DateTime? effectiveFrom;

  const VehicleTariff({
    required this.id,
    required this.version,
    required this.currency,
    required this.localIncludedKm,
    required this.localAmountPaise,
    required this.perKmPaise,
    required this.hourlyPaise,
    required this.extraHourPaise,
    required this.fullDayPaise,
    required this.overnightPaise,
    required this.outstationPerDayPaise,
    required this.outstationPerKmPaise,
    required this.status,
    required this.submittedAt,
    required this.reviewedAt,
    required this.decisionReason,
    required this.effectiveFrom,
  });

  /// The live (customer-facing) version is the APPROVED one.
  bool get isLive => status == TariffStatus.approved;

  /// Human hint matching the product's tariff table.
  String get summary {
    final local = localAmountPaise == null
        ? '—'
        : '₹${(int.tryParse(localAmountPaise!) ?? 0) ~/ 100}';
    final km = localIncludedKm?.toString() ?? '—';
    return 'Up to $km km · $local';
  }
}

/// Result of GET /partner/vehicles — `{ items: [...], total }`.
class PartnerFleet {
  final List<PartnerVehicle> items;
  final int total;

  const PartnerFleet({required this.items, required this.total});

  int get verifiedCount =>
      items.where((v) => v.verificationStatus.isApproved).length;

  int get underReviewCount => items
      .where(
        (v) =>
            v.verificationStatus == PartnerVerificationStatus.submitted ||
            v.verificationStatus == PartnerVerificationStatus.underReview,
      )
      .length;

  int get changesRequiredCount => items
      .where(
        (v) =>
            v.verificationStatus == PartnerVerificationStatus.actionRequired ||
            v.verificationStatus == PartnerVerificationStatus.rejected,
      )
      .length;

  /// A freshly added vehicle the partner has not submitted yet. Without its own
  /// bucket the tally reported "No vehicles yet" over a fleet that visibly
  /// contained one.
  int get awaitingSubmissionCount => items
      .where((v) =>
          v.verificationStatus == PartnerVerificationStatus.pendingSubmission)
      .length;

  /// "2 Verified · 1 Under Review · 1 Changes Required" — the fleet tally.
  String get tallyLine {
    final parts = <String>[
      if (verifiedCount > 0) '$verifiedCount Verified',
      if (underReviewCount > 0) '$underReviewCount Under Review',
      if (awaitingSubmissionCount > 0)
        '$awaitingSubmissionCount Awaiting Submission',
      if (changesRequiredCount > 0) '$changesRequiredCount Changes Required',
    ];
    return parts.isEmpty ? 'No vehicles yet' : parts.join(' · ');
  }
}
