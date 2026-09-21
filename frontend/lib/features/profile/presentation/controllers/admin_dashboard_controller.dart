import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers/app_providers.dart';
import '../../../../core/result/result.dart';
import '../../../bookings/domain/entities/booking_status.dart';
import '../../../bookings/domain/entities/booking_submission_result.dart';
import '../../../bookings/domain/repositories/booking_repository.dart';
import '../../../drivers/domain/entities/driver_duty_status.dart';
import '../../../drivers/domain/entities/driver_profile.dart';
import '../../../drivers/domain/repositories/driver_repository.dart';

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
  String get route => '${booking.pickupAddress} → ${booking.destinationAddress}';

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

/// State for the admin Operations Command Room, sourced from the shared
/// booking and chauffeur stores so it reflects real dispatch activity.
@immutable
class AdminDashboardState {
  final List<AdminDispatchEntry> dispatchEntries;
  final int liveCeremoniesCount;
  final int onDutyCount;
  final bool isLoading;
  final String? errorMessage;

  const AdminDashboardState({
    this.dispatchEntries = const [],
    this.liveCeremoniesCount = 0,
    this.onDutyCount = 0,
    this.isLoading = false,
    this.errorMessage,
  });

  AdminDashboardState copyWith({
    List<AdminDispatchEntry>? dispatchEntries,
    int? liveCeremoniesCount,
    int? onDutyCount,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminDashboardState(
      dispatchEntries: dispatchEntries ?? this.dispatchEntries,
      liveCeremoniesCount: liveCeremoniesCount ?? this.liveCeremoniesCount,
      onDutyCount: onDutyCount ?? this.onDutyCount,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Controller feeding the admin Operations Command Room with live fleet data.
///
/// Reads the same [BookingRepository] and [DriverRepository] stores the driver
/// app writes to, so chauffeur actions (accepting offers, starting trips,
/// completing services) are mirrored here in real time.
class AdminDashboardController extends StateNotifier<AdminDashboardState> {
  final BookingRepository bookingRepository;
  final DriverRepository driverRepository;

  AdminDashboardController({
    required this.bookingRepository,
    required this.driverRepository,
  }) : super(const AdminDashboardState(isLoading: true)) {
    loadDashboard();
  }

  /// Loads the dispatch monitor and duty KPIs.
  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, clearError: true);

    final results = await Future.wait([
      bookingRepository.getDispatchMonitorBookings(),
      driverRepository.getAllDutyStatuses(),
    ]);

    final bookingsResult = results[0]
        as Result<List<BookingSubmissionResult>>;
    final dutyResult = results[1] as Result<Map<String, DriverDutyStatus>>;

    if (!mounted) return; // disposed mid-flight

    final onDutyCount = dutyResult.fold(
      (_) => state.onDutyCount,
      (statuses) => statuses.values
          .where((s) => s != DriverDutyStatus.offline)
          .length,
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

    state = state.copyWith(
      dispatchEntries: entries,
      liveCeremoniesCount: entries.where((e) => e.isLiveCeremony).length,
      onDutyCount: onDutyCount,
      isLoading: false,
      errorMessage: bookingsResult.fold((f) => f.message, (_) => null),
    );
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
    StateNotifierProvider.autoDispose<AdminDashboardController, AdminDashboardState>(
      (ref) {
        return AdminDashboardController(
          bookingRepository: ref.watch(bookingRepositoryProvider),
          driverRepository: ref.watch(driverRepositoryProvider),
        );
      },
    );
