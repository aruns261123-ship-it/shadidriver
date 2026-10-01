import '../../../../core/result/result.dart';
import '../entities/partner_profile.dart';
import '../entities/partner_vehicle.dart';

/// Draft partner profile facts collected during onboarding steps 1–3.
///
/// Field names mirror `RegisterPartnerDto` / `UpdatePartnerProfileDto` on the
/// backend — this is a UI-side holder, NOT a second source of truth. The
/// backend revalidates everything; nothing here is authoritative.
class PartnerRegistrationDraft {
  final String companyName;
  final String? contactName;
  final String baseCity;
  final List<String> serviceCities;
  final List<String> languagesSpoken;
  final int? experienceYears;
  final String? licenseNumber;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? tradeLicenseNumber;
  final String? panNumber;
  final String? gstin;

  const PartnerRegistrationDraft({
    required this.companyName,
    required this.baseCity,
    this.contactName,
    this.serviceCities = const [],
    this.languagesSpoken = const [],
    this.experienceYears,
    this.licenseNumber,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.tradeLicenseNumber,
    this.panNumber,
    this.gstin,
  });

  Map<String, dynamic> toWire() => {
        'companyName': companyName,
        'baseCity': baseCity,
        if (contactName != null) 'contactName': contactName,
        if (serviceCities.isNotEmpty) 'serviceCities': serviceCities,
        if (languagesSpoken.isNotEmpty) 'languagesSpoken': languagesSpoken,
        if (experienceYears != null) 'experienceYears': experienceYears,
        if (licenseNumber != null) 'licenseNumber': licenseNumber,
        if (emergencyContactName != null)
          'emergencyContactName': emergencyContactName,
        if (emergencyContactPhone != null)
          'emergencyContactPhone': emergencyContactPhone,
        if (tradeLicenseNumber != null)
          'tradeLicenseNumber': tradeLicenseNumber,
        if (panNumber != null) 'panNumber': panNumber,
        if (gstin != null) 'gstin': gstin,
      };
}

/// Draft for adding a vehicle — mirrors `AddVehicleDto`.
class PartnerVehicleDraft {
  final String vehicleTypeId;
  final int yearOfManufacture;
  final String registrationNumber;
  final String color;
  final String fuelType;
  final String transmission;
  final String city;
  final List<String> serviceAreas;
  final List<String> amenities;
  final List<String> photoUrls;

  const PartnerVehicleDraft({
    required this.vehicleTypeId,
    required this.yearOfManufacture,
    required this.registrationNumber,
    required this.color,
    required this.fuelType,
    required this.transmission,
    required this.city,
    this.serviceAreas = const [],
    this.amenities = const [],
    this.photoUrls = const [],
  });

  Map<String, dynamic> toWire() => {
        'vehicleTypeId': vehicleTypeId,
        'yearOfManufacture': yearOfManufacture,
        'registrationNumber': registrationNumber,
        'color': color,
        'fuelType': fuelType,
        'transmission': transmission,
        'city': city,
        if (serviceAreas.isNotEmpty) 'serviceAreas': serviceAreas,
        if (amenities.isNotEmpty) 'amenities': amenities,
        if (photoUrls.isNotEmpty) 'photoUrls': photoUrls,
      };
}

/// Edit draft — mirrors `UpdateVehicleDto` (identity fields are NOT editable).
class PartnerVehicleEditDraft {
  final int? yearOfManufacture;
  final String? color;
  final String? fuelType;
  final String? transmission;
  final String? city;
  final List<String>? serviceAreas;
  final List<String>? amenities;
  final List<String>? photoUrls;

  const PartnerVehicleEditDraft({
    this.yearOfManufacture,
    this.color,
    this.fuelType,
    this.transmission,
    this.city,
    this.serviceAreas,
    this.amenities,
    this.photoUrls,
  });

  Map<String, dynamic> toWire() => {
        if (yearOfManufacture != null)
          'yearOfManufacture': yearOfManufacture,
        if (color != null) 'color': color,
        if (fuelType != null) 'fuelType': fuelType,
        if (transmission != null) 'transmission': transmission,
        if (city != null) 'city': city,
        if (serviceAreas != null) 'serviceAreas': serviceAreas,
        if (amenities != null) 'amenities': amenities,
        if (photoUrls != null) 'photoUrls': photoUrls,
      };
}

/// Vehicle document submission — mirrors `AddVehicleDocumentDto`.
/// The storage path references the file the partner uploaded; the backend
/// stores the reference, never the bytes.
class VehicleDocumentDraft {
  final String documentType;
  final String? documentNumber;
  final String storagePath;
  final String mimeType;
  final DateTime? issuedDate;
  final DateTime? expiryDate;

  const VehicleDocumentDraft({
    required this.documentType,
    required this.storagePath,
    required this.mimeType,
    this.documentNumber,
    this.issuedDate,
    this.expiryDate,
  });

  Map<String, dynamic> toWire() => {
        'documentType': documentType,
        'storagePath': storagePath,
        'mimeType': mimeType,
        if (documentNumber != null) 'documentNumber': documentNumber,
        if (issuedDate != null)
          'issuedDate': _dateWire(issuedDate),
        if (expiryDate != null) 'expiryDate': _dateWire(expiryDate),
      };

  static String _dateWire(DateTime? d) =>
      '${d!.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Tariff submission — mirrors `SubmitVehiclePricingDto` exactly. Amounts are
/// PAISE integers; the UI converts rupees at the edge only.
///
/// The customer per-km rate is NOT a partner input: the server DERIVES it
/// from `fuelPricePerLitre ÷ mileageKmPerLitre + ₹10` (any perKmPaise on the
/// wire is ignored), so the draft carries the two formula inputs instead.
class VehicleTariffDraft {
  final int localIncludedKm;
  final int localAmountPaise;

  /// Current fuel price in ₹ per litre (30–500, up to 2 decimals).
  final double fuelPricePerLitre;

  /// Vehicle mileage in km per litre (2–60, up to 1 decimal).
  final double mileageKmPerLitre;
  final int? hourlyPaise;
  final int? extraHourPaise;
  final int? fullDayPaise;
  final int? overnightPaise;
  final int? outstationPerDayPaise;
  final int? outstationPerKmPaise;
  final DateTime? effectiveFrom;

  const VehicleTariffDraft({
    required this.localIncludedKm,
    required this.localAmountPaise,
    required this.fuelPricePerLitre,
    required this.mileageKmPerLitre,
    this.hourlyPaise,
    this.extraHourPaise,
    this.fullDayPaise,
    this.overnightPaise,
    this.outstationPerDayPaise,
    this.outstationPerKmPaise,
    this.effectiveFrom,
  });

  Map<String, dynamic> toWire() => {
        'localIncludedKm': localIncludedKm,
        'localAmountPaise': localAmountPaise,
        'fuelPricePerLitre': fuelPricePerLitre,
        'mileageKmPerLitre': mileageKmPerLitre,
        if (hourlyPaise != null) 'hourlyPaise': hourlyPaise,
        if (extraHourPaise != null) 'extraHourPaise': extraHourPaise,
        if (fullDayPaise != null) 'fullDayPaise': fullDayPaise,
        if (overnightPaise != null) 'overnightPaise': overnightPaise,
        if (outstationPerDayPaise != null)
          'outstationPerDayPaise': outstationPerDayPaise,
        if (outstationPerKmPaise != null)
          'outstationPerKmPaise': outstationPerKmPaise,
        if (effectiveFrom != null)
          'effectiveFrom':
              '${effectiveFrom!.year.toString().padLeft(4, '0')}-'
              '${effectiveFrom!.month.toString().padLeft(2, '0')}-'
              '${effectiveFrom!.day.toString().padLeft(2, '0')}',
      };
}

/// Backend storage constants reused verbatim — no second vocabulary.
abstract final class PartnerDocumentTypes {
  static const partnerLevel = <String>[
    'PARTNER_IDENTITY',
    'DRIVING_LICENCE',
    'TRADE_LICENSE',
    'POLICE_VERIFICATION',
    'GST_CERTIFICATE',
  ];
  static const vehicleLevel = <String>[
    'REGISTRATION_CERTIFICATE',
    'COMMERCIAL_INSURANCE',
    'PUC',
    'FITNESS_CERTIFICATE',
    'COMMERCIAL_PERMIT',
    'VEHICLE_TAX',
  ];
  static const fuelTypes = <String>['PETROL', 'DIESEL', 'CNG', 'ELECTRIC', 'HYBRID'];
  static const transmissions = <String>['AUTOMATIC', 'MANUAL'];
}

abstract interface class PartnerRepository {
  /// POST /partner/registration (idempotent) → the partner profile.
  Future<Result<PartnerProfile>> register(PartnerRegistrationDraft draft);

  /// GET /partner/profile → profile + vehicle/document counts.
  Future<Result<PartnerProfile>> getProfile();

  /// PATCH /partner/profile.
  Future<Result<PartnerProfile>> updateProfile(PartnerRegistrationDraft draft);

  /// GET /partner/vehicles → my fleet.
  Future<Result<PartnerFleet>> listFleet();

  /// POST /partner/vehicles.
  Future<Result<PartnerVehicle>> addVehicle(PartnerVehicleDraft draft);

  /// PATCH /partner/vehicles/:id.
  Future<Result<PartnerVehicle>> updateVehicle(
    String vehicleId,
    PartnerVehicleEditDraft draft,
  );

  /// DELETE /partner/vehicles/:id (refused by the backend when committed).
  Future<Result<void>> removeVehicle(String vehicleId);

  /// POST /partner/vehicles/:id/documents.
  Future<Result<void>> addVehicleDocument(
    String vehicleId,
    VehicleDocumentDraft draft,
  );

  /// GET /partner/vehicles/:id/pricing → version history + live version.
  Future<Result<List<VehicleTariff>>> listTariffs(String vehicleId);

  /// POST /partner/vehicles/:id/pricing → a new PENDING_REVIEW version.
  Future<Result<VehicleTariff>> submitTariff(
    String vehicleId,
    VehicleTariffDraft draft,
  );

  /// POST /partner/submit → partner status becomes SUBMITTED.
  Future<Result<PartnerProfile>> submitForVerification();
}
