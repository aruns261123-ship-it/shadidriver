import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers/app_providers.dart';
import '../../../core/network/api_response.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/shadi_card.dart';
import '../../../core/widgets/shadi_error_view.dart';
import '../../../core/widgets/shadi_loading_indicator.dart';
import '../../../core/widgets/shadi_primary_button.dart';
import '../domain/entities/fleet_availability_result.dart';
import 'controllers/fleet_builder_controller.dart';
import 'controllers/fleet_builder_state.dart';
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

  @override
  void initState() {
    super.initState();
    _typesFuture = _loadTypes();
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
    final success = await _controller.submit(_intent());
    if (!mounted || !success) return;
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFleetPicker(),
          const SizedBox(height: 16),
          if (state.lines.isNotEmpty) ...[
            Text('Your Fleet', style: AppTypography.titleMedium),
            const SizedBox(height: 8),
            for (final line in state.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ShadiCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(line.displayName,
                                style: AppTypography.titleSmall),
                            Text(
                              '${line.seatingCapacity} seats • ${line.vehicleClass}',
                              style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondaryLight),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: line.quantity > 0
                            ? () => _controller
                                .setQuantity(line.vehicleTypeId, line.quantity - 1)
                            : null,
                      ),
                      Text('${line.quantity}',
                          style: AppTypography.titleMedium),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => _controller
                            .setQuantity(line.vehicleTypeId, line.quantity + 1),
                      ),
                    ],
                  ),
                ),
              ),
            Text(
              'Total: ${state.totalVehicles} vehicle(s), '
              'capacity ${state.totalCapacity} guests',
              style: AppTypography.labelLarge,
            ),
          ],
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
              trailing: _state.lines.any((l) => l.vehicleTypeId == t.vehicleTypeId)
                  ? const Icon(Icons.check_circle, color: AppColors.verifiedEmerald)
                  : const Icon(Icons.add_circle_outline),
              onTap: () => _controller.addLine(
                FleetLineState(
                  vehicleTypeId: t.vehicleTypeId,
                  displayName: t.displayName,
                  vehicleClass: t.vehicleClass,
                  seatingCapacity: t.seatingCapacity,
                  quantity: 1,
                ),
              ),
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
