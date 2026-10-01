import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers/app_providers.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/result/result.dart';
import '../../../bookings/domain/entities/booking_status.dart';
import '../../../bookings/domain/entities/booking_submission_result.dart';
import '../../../bookings/domain/repositories/booking_repository.dart';
import '../../../drivers/domain/entities/driver_duty_status.dart';
import '../../../drivers/domain/entities/driver_profile.dart';
import '../../../drivers/domain/repositories/driver_repository.dart';
import '../../../vehicles/domain/entities/vehicle_summary.dart';
import '../../../vehicles/domain/repositories/vehicle_repository.dart';

/// One live row on the admin dispatch monitor, enriched with the chauffeur's
/// display name resolved from the roster.
@immutable
class AdminDispatchEntry {
  final BookingSubmissionResult booking;
  final String chauffeurDisplayName;

  const AdminDispatchEntry({
    required this.booking,
    required this.chauffeurDisplayName,
  });

  String get bookingReference => booking.bookingReference;
  String get ceremonyType => booking.ceremonyType;
  String get vehicleName => booking.vehicleName;
  String get route =>
      '${booking.pickupAddress} → ${booking.destinationAddress}';

  /// Operations-floor status label derived from the authoritative lifecycle.
  String get statusLabel => switch (booking.status) {
    BookingStatus.requested => 'AWAITING ACCEPTANCE',
    BookingStatus.driverAccepted => 'DRIVER ACCEPTED',
    BookingStatus.driverAssigned => 'CHAUFFEUR ASSIGNED',
    BookingStatus.driverArriving => 'EN ROUTE',
    BookingStatus.arrived => 'ARRIVED AT PICKUP',
    BookingStatus.tripStarted => 'CEREMONY IN PROGRESS',
    BookingStatus.emergencyReplacement => 'STANDBY DISPATCHED',
    BookingStatus.paymentPending => 'PAYMENT PENDING',
    BookingStatus.confirmed => 'BOOKING SECURED',
    _ => booking.status.displayLabel.toUpperCase(),
  };

  /// Whether the ceremony is actively underway (accepted through procession).
  bool get isLiveCeremony =>
      booking.status != BookingStatus.requested &&
      booking.status != BookingStatus.paymentPending &&
      booking.status != BookingStatus.confirmed;
}

/// One fleet vehicle with a live availability status derived from current
/// dispatch assignments.
@immutable
class AdminFleetEntry {
  final VehicleSummary vehicle;

  /// Live dispatch status: the vehicle's ceremony-stage booking, if engaged.
  final BookingSubmissionResult? activeAssignment;

  const AdminFleetEntry({required this.vehicle, this.activeAssignment});

  String get displayName => '${vehicle.make} ${vehicle.model}';
  String get registrationNumber => vehicle.registrationNumber;
  String get vehicleClass => vehicle.vehicleClass;

  String get statusLabel {
    final assignment = activeAssignment;
    if (assignment == null) {
      return vehicle.isAvailableNow ? 'AVAILABLE' : 'OFF DUTY';
    }
    return switch (assignment.status) {
      BookingStatus.driverAccepted ||
      BookingStatus.confirmed ||
      BookingStatus.driverAssigned => 'RESERVED',
      BookingStatus.driverArriving => 'EN ROUTE',
      BookingStatus.arrived ||
      BookingStatus.tripStarted ||
      BookingStatus.emergencyReplacement => 'ON CEREMONY',
      _ => 'ENGAGED',
    };
  }

  bool get isEngaged => activeAssignment != null;
}

/// REAL customer counts from `GET /admin/customers/stats` (PostgreSQL).
@immutable
class AdminCustomerStats {
  final int totalCustomers;
  final int newCustomers30d;
  final int activeCustomers;

  const AdminCustomerStats({
    required this.totalCustomers,
    required this.newCustomers30d,
    required this.activeCustomers,
  });

  factory AdminCustomerStats.fromWire(Map<String, dynamic> json) =>
      AdminCustomerStats(
        totalCustomers: (json['total_customers'] as num?)?.toInt() ?? 0,
        newCustomers30d: (json['new_customers_30d'] as num?)?.toInt() ?? 0,
        activeCustomers: (json['active_customers'] as num?)?.toInt() ?? 0,
      );
}

/// State for the admin Operations Command Room, sourced from the shared
/// booking, chauffeur, and vehicle stores so it reflects real fleet activity.
@immutable
class AdminDashboardState {
  final List<AdminDispatchEntry> dispatchEntries;
  final List<AdminFleetEntry> fleetEntries;
  final int liveCeremoniesCount;
  final int onDutyCount;

  /// Real customer counts from the backend. Null while loading / on failure —
  /// the UI shows a dash, never a sample value.
  final AdminCustomerStats? customerStats;
  final bool isLoading;
  final String? errorMessage;

  const AdminDashboardState({
    this.dispatchEntries = const [],
    this.fleetEntries = const [],
    this.liveCeremoniesCount = 0,
    this.onDutyCount = 0,
    this.customerStats,
    this.isLoading = false,
    this.errorMessage,
  });

  AdminDashboardState copyWith({
    List<AdminDispatchEntry>? dispatchEntries,
    List<AdminFleetEntry>? fleetEntries,
    int? liveCeremoniesCount,
    int? onDutyCount,
    AdminCustomerStats? customerStats,
    bool clearCustomerStats = false,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminDashboardState(
      dispatchEntries: dispatchEntries ?? this.dispatchEntries,
      fleetEntries: fleetEntries ?? this.fleetEntries,
      liveCeremoniesCount: liveCeremoniesCount ?? this.liveCeremoniesCount,
      onDutyCount: onDutyCount ?? this.onDutyCount,
      customerStats:
          clearCustomerStats ? null : (customerStats ?? this.customerStats),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Controller feeding the admin Operations Command Room with live fleet data.
///
/// Reads the same booking, driver, and vehicle stores the rest of the app
/// writes to, so chauffeur actions (accepting offers, starting trips,
/// completing services) are mirrored here in real time.
class AdminDashboardController extends StateNotifier<AdminDashboardState> {
  final BookingRepository bookingRepository;
  final DriverRepository driverRepository;
  final VehicleRepository vehicleRepository;

  /// REAL customer counts fetcher (`GET /admin/customers/stats`). The provider
  /// injects it in production mode and leaves it null in mock-data mode — so
  /// offline UI development and widget tests never touch HTTP, and the UI
  /// shows a dash instead of a fabricated number.
  final Future<AdminCustomerStats?> Function()? fetchCustomerStats;

  AdminDashboardController({
    required this.bookingRepository,
    required this.driverRepository,
    required this.vehicleRepository,
    this.fetchCustomerStats,
  }) : super(const AdminDashboardState(isLoading: true)) {
    loadDashboard();
  }

  /// Loads the dispatch monitor, duty KPIs, and live fleet registry.
  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, clearError: true);

    final results = await Future.wait([
      bookingRepository.getDispatchMonitorBookings(),
      driverRepository.getAllDutyStatuses(),
      vehicleRepository.getAvailableVehicles(),
    ]);

    final bookingsResult = results[0] as Result<List<BookingSubmissionResult>>;
    final dutyResult = results[1] as Result<Map<String, DriverDutyStatus>>;
    final vehiclesResult = results[2] as Result<List<VehicleSummary>>;

    // REAL customer counts (server-derived; never sample values). Null
    // fetcher (mock-data mode) or a failed call renders a dash — never a
    // fabricated number.
    AdminCustomerStats? stats;
    final fetchStats = fetchCustomerStats;
    if (fetchStats != null) {
      try {
        stats = await fetchStats();
      } catch (_) {
        stats = null;
      }
    }

    if (!mounted) return; // disposed mid-flight

    final onDutyCount = dutyResult.fold(
      (_) => state.onDutyCount,
      (statuses) =>
          statuses.values.where((s) => s != DriverDutyStatus.offline).length,
    );

    final bookings = bookingsResult.dataOrNull ?? const [];
    final chauffeurNames = await _resolveChauffeurNames(bookings);

    if (!mounted) return;

    final entries = bookings
        .map(
          (b) => AdminDispatchEntry(
            booking: b,
            chauffeurDisplayName: chauffeurNames[b.chauffeurId] ?? 'Unassigned',
          ),
        )
        .toList();

    // Derive fleet statuses: a vehicle is ENGAGED when an assigned booking
    // (accepted or in-flight) references it. Unclaimed offers (REQUESTED) and
    // terminal states don't engage a vehicle.
    const nonEngagingStatuses = {
      BookingStatus.requested,
      BookingStatus.completed,
      BookingStatus.rejected,
      BookingStatus.expired,
      BookingStatus.cancelled,
      BookingStatus.paymentFailed,
    };
    final vehicles = vehiclesResult.dataOrNull ?? const <VehicleSummary>[];
    final fleetEntries = vehicles.map((v) {
      final engaged = bookings.where(
        (b) =>
            b.vehicleName.contains('${v.make} ${v.model}') &&
            !nonEngagingStatuses.contains(b.status),
      );
      return AdminFleetEntry(
        vehicle: v,
        activeAssignment: engaged.isEmpty ? null : engaged.first,
      );
    }).toList();

    state = state.copyWith(
      dispatchEntries: entries,
      fleetEntries: fleetEntries,
      liveCeremoniesCount: entries.where((e) => e.isLiveCeremony).length,
      onDutyCount: onDutyCount,
      customerStats: stats,
      isLoading: false,
      errorMessage: bookingsResult.fold((f) => f.message, (_) => null),
    );
  }

  /// Manual dispatch override: force-dispatches an emergency standby
  /// chauffeur for a booking that is still awaiting driver acceptance.
  ///
  /// The standby chauffeur is the first AVAILABLE driver on the roster's duty
  /// board (PRD: "manual dispatch overrides & emergency SOS"). Returns null on
  /// failure with [errorMessage] populated, or the updated booking.
  Future<BookingSubmissionResult?> dispatchEmergencyStandby(
    String bookingId,
  ) async {
    // Pick an available chauffeur from the live duty board.
    final dutyResult = await driverRepository.getAllDutyStatuses();
    final duties = dutyResult.dataOrNull ?? const {};
    String? standbyId;
    for (final entry in duties.entries) {
      if (entry.value == DriverDutyStatus.available) {
        standbyId = entry.key;
        break;
      }
    }
    if (standbyId == null) {
      state = state.copyWith(
        errorMessage: 'No AVAILABLE chauffeur on the duty board for standby.',
      );
      return null;
    }

    final store = bookingRepository as dynamic;
    final Result<BookingSubmissionResult> result = store
        .dispatchEmergencyReplacement(
          bookingId: bookingId,
          driverId: standbyId,
        );

    final failure = result.fold((f) => f, (_) => null);
    if (failure != null) {
      state = state.copyWith(errorMessage: failure.message);
      return null;
    }

    // Mirror the override onto the monitor immediately.
    await loadDashboard();
    return result.dataOrNull;
  }

  /// Resolves chauffeur IDs into display names via the roster, falling back to
  /// the raw ID when a profile cannot be found.
  Future<Map<String, String>> _resolveChauffeurNames(
    List<BookingSubmissionResult> bookings,
  ) async {
    final chauffeurIds = bookings
        .map((b) => b.chauffeurId)
        .where((id) => id.isNotEmpty)
        .toSet();

    final names = <String, String>{};
    for (final id in chauffeurIds) {
      final profileResult = await driverRepository.getDriverById(id);
      profileResult.fold(
        (_) => names[id] = id,
        (DriverProfile profile) => names[id] = profile.fullName,
      );
    }
    return names;
  }
}

/// Provider for the admin Operations Command Room.
final adminDashboardControllerProvider =
    StateNotifierProvider.autoDispose<
      AdminDashboardController,
      AdminDashboardState
    >((ref) {
      final useMock = ref.watch(
        environmentConfigProvider.select((c) => c.useMockData),
      );
      return AdminDashboardController(
        bookingRepository: ref.watch(bookingRepositoryProvider),
        driverRepository: ref.watch(driverRepositoryProvider),
        vehicleRepository: ref.watch(vehicleRepositoryProvider),
        // Real HTTP stats fetch ONLY in real mode; mock mode renders a dash.
        fetchCustomerStats: useMock
            ? null
            : () async {
                final response = await ref.watch(apiClientProvider).get<Map<String, dynamic>>(
                      '${ApiPaths.v1}/admin/customers/stats',
                    );
                final envelope = ApiEnvelope.fromJson(response.data);
                final data = (envelope.data as Map<String, dynamic>?) ?? const {};
                return AdminCustomerStats.fromWire(data);
              },
      );
    });
