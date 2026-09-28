import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers/app_providers.dart';
import '../../../app/router/route_paths.dart';
import '../../../core/network/api_response.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/shadi_card.dart';
import '../../../core/widgets/shadi_error_view.dart';
import '../../../core/widgets/shadi_loading_indicator.dart';
import '../../../core/widgets/shadi_primary_button.dart';
import '../../../core/widgets/shadi_quantity_stepper.dart';
import '../domain/entities/fleet_availability_result.dart';
import '../domain/entities/guest_fleet_selection.dart';
import 'controllers/fleet_builder_controller.dart';
import 'controllers/fleet_builder_state.dart';
import 'controllers/guest_fleet_selection_controller.dart';
import 'group_booking_detail_screen.dart';

/// Group / multi-vehicle booking builder.
///
/// Lets the customer say "Innova × 7" and shows the backend's real
/// availability — requested vs available, the explicit shortfall, and
/// alternatives. A partial composition can only proceed after the customer
/// EXPLICITLY approves it; vehicles are never silently substituted.
class GroupBookingScreen extends ConsumerStatefulWidget {
  const GroupBookingScreen({super.key});

  @override
  ConsumerState<GroupBookingScreen> createState() => _GroupBookingScreenState();
}

class _GroupBookingScreenState extends ConsumerState<GroupBookingScreen> {
  late Future<List<FleetLineState>> _typesFuture;

  /// Captured so `dispose` can release the suppression without touching `ref`
  /// after the element is gone.
  StateController<bool>? _barSuppression;

  @override
  void initState() {
    super.initState();
    _typesFuture = _loadTypes();
    // This screen IS the selection, so the shell's persistent bar steps aside
    // (otherwise it would offer to open the page we are already on). Deferred
    // out of initState: a provider must not be modified during a life-cycle.
    _barSuppression = ref.read(selectionBarSuppressedProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barSuppression?.state = true;
    });
  }

  @override
  void dispose() {
    final suppression = _barSuppression;
    // Deferred for the same reason: unmounting happens inside a build.
    if (suppression != null) {
      Future.microtask(() => suppression.state = false);
    }
    super.dispose();
  }

  Future<List<FleetLineState>> _loadTypes() async {
    final response = await ref.read(apiClientProvider).get<Map<String, dynamic>>(
          '${ApiPaths.v1}/vehicles/types',
        );
    final envelope = ApiEnvelope.fromJson(response.data);
    final items = (envelope.data as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    return items.map((t) {
      return FleetLineState(
        vehicleTypeId: (t['id'] as String?) ?? '',
        displayName:
            (t['displayName'] as String?) ?? (t['display_name'] as String?) ?? '',
        vehicleClass: (t['vehicleClass'] as String?) ?? '',
        seatingCapacity: (t['seatingCap'] as num?)?.toInt() ?? 4,
        quantity: 0,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FleetLineState>>(
      future: _typesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: AppColors.backgroundLight,
            appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
            body: const Center(child: ShadiLoadingIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            backgroundColor: AppColors.backgroundLight,
            appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
            body: ShadiErrorView(
              message: 'Unable to load vehicle types: ${snapshot.error}',
              onRetry: () => setState(() => _typesFuture = _loadTypes()),
            ),
          );
        }
        return _GroupBookingForm(types: snapshot.data!);
      },
    );
  }
}

class _GroupBookingForm extends ConsumerStatefulWidget {
  const _GroupBookingForm({required this.types});

  final List<FleetLineState> types;

  @override
  ConsumerState<_GroupBookingForm> createState() => _GroupBookingFormState();
}

class _GroupBookingFormState extends ConsumerState<_GroupBookingForm> {
  final _pickupCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();
  DateTime _start = DateTime.now().add(const Duration(days: 7, hours: 4));
  int _passengerCount = 12;

  GroupBookingController get _controller =>
      ref.read(groupBookingControllerProvider(widget.types).notifier);

  GroupBookingState get _state =>
      ref.watch(groupBookingControllerProvider(widget.types));

  @override
  void initState() {
    super.initState();
    // DEFERRED ON PURPOSE: restoring writes into the group-booking controller,
    // and Riverpod forbids modifying a provider during a widget life-cycle.
    // Running it from `initState` threw "Tried to modify a provider while the
    // widget tree was building" on EXACTLY the path a visitor takes when they
    // tap "Review Selection" with cars already chosen — which is why the
    // review screen could not be relied on to open at all in a debug build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _restoreGuestSelection();
    });
  }

  /// GUEST-FIRST STATE RESTORE: a visitor who composed "Thar × 2, Scorpio × 1"
  /// while browsing (or who was bounced to login mid-flow) resumes here with
  /// their selection AND trip details intact — never re-picking from scratch.
  void _restoreGuestSelection() {
    final guest = ref.read(guestFleetSelectionProvider);

    // Restore previously chosen vehicles (only types this builder offers).
    final offered = {for (final t in widget.types) t.vehicleTypeId: t};
    for (final line in guest.lines) {
      final type = offered[line.vehicleTypeId];
      if (type != null && line.quantity > 0) {
        _controller.setQuantity(line.vehicleTypeId, line.quantity);
      }
    }

    // Restore trip context captured before the login detour.
    final trip = guest.trip;
    if (trip.pickupAddress != null) _pickupCtrl.text = trip.pickupAddress!;
    if (trip.destinationAddress != null) {
      _destinationCtrl.text = trip.destinationAddress!;
    }
    if (trip.contactName != null) _contactNameCtrl.text = trip.contactName!;
    if (trip.contactPhone != null) _contactPhoneCtrl.text = trip.contactPhone!;

    final nextPassenger =
        (trip.passengerCount != null && trip.passengerCount! >= 2)
            ? trip.passengerCount!
            : _passengerCount;
    final nextStart =
        (trip.serviceStart != null && trip.serviceStart!.isAfter(DateTime.now()))
            ? trip.serviceStart!
            : _start;
    if (nextPassenger != _passengerCount || nextStart != _start) {
      setState(() {
        _passengerCount = nextPassenger;
        _start = nextStart;
      });
    }
  }

  /// What the review screen currently holds, as app-level selection lines.
  List<GuestFleetLine> _guestLines() => ref
      .read(groupBookingControllerProvider(widget.types))
      .selectedLines
      .map(
        (l) => GuestFleetLine(
          vehicleTypeId: l.vehicleTypeId,
          displayName: l.displayName,
          vehicleClass: l.vehicleClass,
          seatingCapacity: l.seatingCapacity,
          quantity: l.quantity,
        ),
      )
      .toList(growable: false);

  /// Writes the CURRENT composition (and trip form) back into the app-level
  /// selection on every edit — not only before the login detour.
  ///
  /// The previous version only pushed lines with `quantity > 0` and never
  /// deleted anything, so removing a car here left it in the shared selection:
  /// the summary bar kept counting it and the search card kept showing it as
  /// "Selected". [replaceLines] mirrors the composition exactly, deletions
  /// included, so the removal is visible everywhere the moment it happens.
  void _syncToGuestSelection() {
    ref.read(guestFleetSelectionProvider.notifier).replaceLines(_guestLines());
    ref.read(guestFleetSelectionProvider.notifier).updateTrip(
          GuestTripDetails(
            ceremonyType: 'Baraat',
            city: 'Delhi NCR',
            pickupAddress: _pickupCtrl.text.trim().isEmpty
                ? null
                : _pickupCtrl.text.trim(),
            destinationAddress: _destinationCtrl.text.trim().isEmpty
                ? null
                : _destinationCtrl.text.trim(),
            contactName: _contactNameCtrl.text.trim().isEmpty
                ? null
                : _contactNameCtrl.text.trim(),
            contactPhone: _contactPhoneCtrl.text.trim().isEmpty
                ? null
                : _contactPhoneCtrl.text.trim(),
            serviceStart: _start,
            serviceEnd: _start.add(const Duration(hours: 8)),
            passengerCount: _passengerCount,
          ),
        );
  }

  /// Adding from the catalog list on the review screen: creates the line and,
  /// crucially, writes it straight back into the shared selection — the old
  /// picker did neither (its `addLine` was a no-op and it never synced).
  void _addLineFromPicker(FleetLineState type) {
    _controller.addLine(
      FleetLineState(
        vehicleTypeId: type.vehicleTypeId,
        displayName: type.displayName,
        vehicleClass: type.vehicleClass,
        seatingCapacity: type.seatingCapacity,
        quantity: 1,
      ),
    );
    _syncToGuestSelection();
  }

  /// Quantity edit from the review screen (or a card stepper). 0 removes.
  void _changeQuantity(String vehicleTypeId, int quantity) {
    if (quantity <= 0) {
      _removeLine(vehicleTypeId);
      return;
    }
    _controller.setQuantity(vehicleTypeId, quantity);
    _syncToGuestSelection();
  }

  /// Row-level Remove (and the remove step of the stepper).
  void _removeLine(String vehicleTypeId) {
    _controller.removeLine(vehicleTypeId);
    _syncToGuestSelection();
  }

  /// Back to browsing with the selection untouched — reviewing is guest work
  /// and must never trap the visitor inside the review screen.
  void _continueBrowsing() {
    _syncToGuestSelection();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoutePaths.customerHome);
    }
  }

  /// Named auth detour: whatever the visitor was doing, they come back HERE
  /// with the same cars and trip details (the selection is app-level).
  void _pushAuth() {
    context.push(
      '${RoutePaths.auth}?redirect='
      '${Uri.encodeComponent(RoutePaths.customerGroupBooking)}',
    );
  }

  /// "Continue to Booking" — the ONE protected action on this screen.
  ///
  /// A guest is authenticated first (the selection survives the detour); an
  /// authenticated customer goes straight through availability and submission.
  Future<void> _continueToBooking() async {
    if (ref
        .read(groupBookingControllerProvider(widget.types))
        .selectedLines
        .isEmpty) {
      return;
    }
    if (!ref.read(activeSessionProvider).isAuthenticated) {
      _syncToGuestSelection();
      _pushAuth();
      return;
    }
    if (ref.read(groupBookingControllerProvider(widget.types)).availability ==
        null) {
      await _checkAvailability();
      if (!mounted) return;
    }
    final fresh = ref.read(groupBookingControllerProvider(widget.types));
    if (!fresh.canSubmit || fresh.isSubmitting) return;
    await _submit();
  }

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _destinationCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (time == null) return;
    setState(() {
      _start = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  GroupBookingIntent _intent() => GroupBookingIntent(
        ceremonyType: 'Baraat',
        city: 'Delhi NCR',
        pickupAddress: _pickupCtrl.text.trim(),
        destinationAddress: _destinationCtrl.text.trim(),
        primaryContactName: _contactNameCtrl.text.trim(),
        primaryContactPhone: _contactPhoneCtrl.text.trim(),
        serviceStartDateTime: _start,
        serviceEndDateTime: _start.add(const Duration(hours: 8)),
        passengerCount: _passengerCount,
      );

  Future<void> _checkAvailability() async {
    final ok = await _controller.checkAvailability(_intent());
    if (!mounted) return;
    if (!ok) return;
    final availability = ref
        .read(groupBookingControllerProvider(widget.types))
        .availability;
    if (availability != null && !availability.isFullyAvailable) {
      await _showShortfallDialog(availability);
    }
  }

  /// EXPLICIT shortfall confirmation — never an automatic substitution.
  Future<void> _showShortfallDialog(FleetAvailabilityResult availability) async {
    final approved = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.urgentSaffron),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Fleet Shortfall — Your Choice Required',
                      style: AppTypography.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                availability.message,
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 12),
              if (availability.alternativeSuggestions.isNotEmpty) ...[
                Text('Suggested alternatives:',
                    style: AppTypography.labelLarge),
                const SizedBox(height: 8),
                for (final alt in availability.alternativeSuggestions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• ${alt.modelName} — ${alt.suggestedCount} available '
                      '(${alt.capacityPerUnit} seats each)',
                      style: AppTypography.bodySmall,
                    ),
                  ),
                const SizedBox(height: 8),
              ],
              const Text(
                'We will NOT substitute vehicles without your approval. '
                'Keep the reduced fleet, or search another date.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Search Another Date'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBurgundy,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Keep This Fleet'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (approved == true) {
      _controller.approveShortfall();
    } else {
      _controller.rejectShortfall();
    }
  }

  Future<void> _submit() async {
    // ACTION-BASED AUTH: composing and reviewing the fleet is guest work;
    // creating a booking is not. Persist the selection first, then bounce to
    // sign-in with a redirect BACK to this flow — after OTP the customer
    // lands right here with the same cars and trip details restored.
    final session = ref.read(activeSessionProvider);
    if (!session.isAuthenticated) {
      _syncToGuestSelection();
      _pushAuth();
      return;
    }
    final success = await _controller.submit(_intent());
    if (!mounted || !success) return;
    // The selection became a real booking — it has served its purpose.
    ref.read(guestFleetSelectionProvider.notifier).consume();
    final group = ref
        .read(groupBookingControllerProvider(widget.types))
        .submittedGroup;
    if (group == null) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GroupBookingDetailScreen(groupBookingId: group.parentBookingId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      floatingActionButton: state.lines.isNotEmpty && state.stage == GroupBookingStage.build
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primaryBurgundy,
              foregroundColor: Colors.white,
              onPressed: state.isChecking ? null : _checkAvailability,
              icon: state.isChecking
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.event_available_rounded),
              label: const Text('Check Availability'),
            )
          : null,
      // The review screen's own action bar. `Continue to Booking` is the one
      // protected action; everything above it stays guest-accessible.
      bottomNavigationBar: _buildActionBar(state),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildYourSelection(state),
          const SizedBox(height: 16),
          _buildFleetPicker(),
          const SizedBox(height: 16),
          _buildEventDetails(),
          const SizedBox(height: 16),
          if (state.availability != null) _buildAvailabilityCard(state),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              state.errorMessage!,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.urgentSaffron),
            ),
          ],
          if (state.stage.index >= GroupBookingStage.availability.index &&
              state.availability != null) ...[
            const SizedBox(height: 16),
            ShadiPrimaryButton(
              text: state.isSubmitting
                  ? 'Creating Group Booking…'
                  : 'Confirm Group Booking',
              onPressed:
                  state.canSubmit && !state.isSubmitting ? _submit : null,
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// YOUR SELECTION — the subject of this screen, not a footnote.
  ///
  /// Every line is independently editable (quantity / remove) and each edit is
  /// written straight back into the app-level selection, so the summary bar,
  /// the search cards and the details bar all change immediately — no refresh,
  /// no navigating back to trigger a sync.
  Widget _buildYourSelection(GroupBookingState state) {
    if (state.selectedLines.isEmpty) return _buildEmptySelection();
    return ShadiCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR SELECTION',
            style: AppTypography.labelLarge.copyWith(
              letterSpacing: 1.2,
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 12),
          for (final line in state.selectedLines) _buildSelectionLine(line),
          const Divider(color: AppColors.borderLight),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${state.totalVehicles} '
                  '${state.totalVehicles == 1 ? 'Car' : 'Cars'} Selected',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.primaryBurgundy,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'seats ${state.totalCapacity}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Removing the last vehicle lands here automatically, so the visitor is
  /// never left staring at a blank review screen.
  Widget _buildEmptySelection() => ShadiCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'YOUR SELECTION',
              style: AppTypography.labelLarge.copyWith(
                letterSpacing: 1.2,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 12),
            Text('No cars selected yet', style: AppTypography.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Browse the fleet and add the cars you like.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _continueBrowsing,
                icon: const Icon(Icons.explore_outlined, size: 18),
                label: const Text('Explore Cars'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  foregroundColor: AppColors.primaryBurgundy,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildSelectionLine(FleetLineState line) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type thumbnail. The public vehicle-type payload carries no
              // image, so this is a deliberate placeholder, never a fake photo.
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.secondarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.directions_car_rounded,
                  color: AppColors.textTertiaryLight,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.displayName,
                      style: AppTypography.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${line.seatingCapacity} seats • ${line.vehicleClass}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${line.quantity} '
                      '${line.quantity == 1 ? 'Car' : 'Cars'}',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.primaryBurgundy,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // `−` at one removes the line, so no vehicle can get stuck in the
          // selection. Wrap (not Row) so a large text scale cannot overflow.
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                ShadiQuantityStepper(
                  quantity: line.quantity,
                  compact: false,
                  onDecrement: () =>
                      _changeQuantity(line.vehicleTypeId, line.quantity - 1),
                  onIncrement: () =>
                      _changeQuantity(line.vehicleTypeId, line.quantity + 1),
                ),
                TextButton.icon(
                  onPressed: () => _removeLine(line.vehicleTypeId),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Remove'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryBurgundy,
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(GroupBookingState state) {
    if (state.selectedLines.isEmpty) return const SizedBox.shrink();
    return Material(
      elevation: 8,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _continueBrowsing,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  foregroundColor: AppColors.primaryBurgundy,
                ),
                child: const Text(
                  'Continue Browsing',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: state.isSubmitting ? null : _continueToBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBurgundy,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 46),
                ),
                child: Text(
                  state.isSubmitting ? 'Creating…' : 'Continue to Booking',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFleetPicker() {
    return ShadiCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add Vehicles', style: AppTypography.titleMedium),
          const SizedBox(height: 8),
          for (final t in widget.types)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(t.displayName, style: AppTypography.titleSmall),
              subtitle: Text('${t.seatingCapacity} seats • ${t.vehicleClass}',
                  style: AppTypography.bodySmall),
              // The ✓ must mean SELECTED. It used to be true for every type,
              // because the composition is seeded with the whole catalogue at
              // quantity 0 and the check only asked whether a line EXISTED.
              trailing: _state.selectedLines.any(
                      (l) => l.vehicleTypeId == t.vehicleTypeId)
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '×'
                          '${_state.selectedLines.firstWhere((l) => l.vehicleTypeId == t.vehicleTypeId).quantity}',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.primaryBurgundy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.verifiedEmerald,
                        ),
                      ],
                    )
                  : const Icon(Icons.add_circle_outline),
              onTap: () => _addLineFromPicker(t),
            ),
        ],
      ),
    );
  }

  Widget _buildEventDetails() {
    return ShadiCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Event Details', style: AppTypography.titleMedium),
          const SizedBox(height: 12),
          TextFormField(
            controller: _pickupCtrl,
            decoration: const InputDecoration(
              labelText: 'Pickup Address',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _destinationCtrl,
            decoration: const InputDecoration(
              labelText: 'Destination / Venue',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _contactNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Host Name',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _contactPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Host Phone',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDateTime,
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: Text(
                    '${_start.day}/${_start.month}/${_start.year} • '
                    '${_start.hour.toString().padLeft(2, '0')}:'
                    '${_start.minute.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _passengerCount,
                  decoration: const InputDecoration(
                    labelText: 'Passengers',
                    border: OutlineInputBorder(),
                  ),
                  items: [for (var i = 2; i <= 60; i += 2) i]
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                      .toList(),
                  onChanged: (n) => setState(() => _passengerCount = n ?? 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityCard(GroupBookingState state) {
    final availability = state.availability!;
    final color =
        availability.isFullyAvailable ? AppColors.verifiedEmerald : AppColors.urgentSaffron;
    return ShadiCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                availability.isFullyAvailable
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  availability.isFullyAvailable
                      ? 'Full fleet available'
                      : 'Partial availability — your choice required',
                  style: AppTypography.titleSmall.copyWith(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(availability.message, style: AppTypography.bodyMedium),
          if (availability.alternativeSuggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Alternatives:', style: AppTypography.labelLarge),
            for (final alt in availability.alternativeSuggestions)
              Text(
                '• ${alt.modelName} × ${alt.suggestedCount} '
                '(${alt.capacityPerUnit} seats each)',
                style: AppTypography.bodySmall,
              ),
          ],
          if (state.hasShortfall && !state.shortfallApproved) ...[
            const SizedBox(height: 8),
            Text(
              'Approval required to keep this reduced fleet.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.urgentSaffron),
            ),
            const SizedBox(height: 8),
            ShadiPrimaryButton(
              text: 'Review Shortfall',
              onPressed: () => _showShortfallDialog(availability),
            ),
          ],
        ],
      ),
    );
  }
}
