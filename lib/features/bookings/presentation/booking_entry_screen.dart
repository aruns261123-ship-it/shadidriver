import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/shadi_card.dart';
import '../../../../core/widgets/shadi_error_view.dart';
import '../../../../core/widgets/shadi_loading_indicator.dart';
import '../../../../core/widgets/shadi_primary_button.dart';
import '../../../../core/widgets/shadi_secondary_button.dart';
import '../../../../core/widgets/shadi_text_field.dart';
import '../../vehicles/domain/entities/vehicle_details.dart';
import '../../vehicles/presentation/controllers/vehicle_details_controller.dart';
import 'controllers/booking_draft_controller.dart';
import 'widgets/booking_draft_summary_card.dart';

/// Milestone 4A - Customer Booking Entry & Event Details Screen.
///
/// Implements the flow:
/// Vehicle Details -> Book Now -> Booking Entry -> Event/Ceremony -> Date/Time -> Pickup/Destination -> Passenger Details -> Continue
class BookingEntryScreen extends ConsumerStatefulWidget {
  final String vehicleId;

  const BookingEntryScreen({super.key, required this.vehicleId});

  @override
  ConsumerState<BookingEntryScreen> createState() => _BookingEntryScreenState();
}

class _BookingEntryScreenState extends ConsumerState<BookingEntryScreen> {
  // Text editing controllers for section inputs
  late final TextEditingController _instructionsController;
  late final TextEditingController _pickupController;
  late final TextEditingController _destinationController;
  late final TextEditingController _venueNameController;
  late final TextEditingController _landmarkController;
  late final TextEditingController _contactNameController;
  late final TextEditingController _contactPhoneController;
  late final TextEditingController _altPhoneController;

  bool _initializedWithDefaults = false;

  @override
  void initState() {
    super.initState();
    _instructionsController = TextEditingController();
    _pickupController = TextEditingController();
    _destinationController = TextEditingController();
    _venueNameController = TextEditingController();
    _landmarkController = TextEditingController();
    _contactNameController = TextEditingController();
    _contactPhoneController = TextEditingController();
    _altPhoneController = TextEditingController();
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    _pickupController.dispose();
    _destinationController.dispose();
    _venueNameController.dispose();
    _landmarkController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _altPhoneController.dispose();
    super.dispose();
  }

  void _syncControllersWithDraft(BookingDraftState draftState) {
    if (!_initializedWithDefaults) {
      _initializedWithDefaults = true;
      _instructionsController.text = draftState.draft.specialInstructions;
      _pickupController.text = draftState.draft.pickupAddress;
      _destinationController.text = draftState.draft.destinationAddress;
      _venueNameController.text = draftState.draft.venueName;
      _landmarkController.text = draftState.draft.landmark;
      _contactNameController.text = draftState.draft.primaryContactName;
      _contactPhoneController.text = draftState.draft.primaryContactPhone;
      _altPhoneController.text = draftState.draft.alternateContactPhone ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleAsync = ref.watch(vehicleDetailsProvider(widget.vehicleId));

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.primaryBurgundy,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Booking Experience',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.primaryBurgundy,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: vehicleAsync.when(
        loading: () => const ShadiLoadingIndicator(
          message: 'Loading vehicle booking configuration...',
        ),
        error: (err, _) => ShadiErrorView(
          message: 'Unable to initialize booking draft. Vehicle not found.',
          onRetry: () => ref.refresh(vehicleDetailsProvider(widget.vehicleId)),
        ),
        data: (vehicle) {
          final draftState = ref.watch(bookingDraftControllerProvider(vehicle));
          final draftNotifier = ref.read(
            bookingDraftControllerProvider(vehicle).notifier,
          );

          _syncControllersWithDraft(draftState);

          if (draftState.isSaved && draftState.savedDraft != null) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: BookingDraftSummaryCard(
                draft: draftState.savedDraft!,
                onDismiss: () => context.go(RoutePaths.customerHome),
              ),
            );
          }

          return SafeArea(
            child: Column(
              children: [
                // Top Vehicle & Flow Header
                _buildVehicleHeader(vehicle),

                // Stepper Indicator
                _buildStepIndicator(draftState.activeStep),

                // Error Banner (if validation failed)
                if (draftState.errorMessage != null)
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.errorRed.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.errorRed,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            draftState.errorMessage!,
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.errorRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Active Step Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: switch (draftState.activeStep) {
                      0 => _buildCeremonyStep(
                        vehicle,
                        draftState,
                        draftNotifier,
                      ),
                      1 => _buildDateTimeStep(
                        vehicle,
                        draftState,
                        draftNotifier,
                      ),
                      2 => _buildLocationsStep(draftState, draftNotifier),
                      3 => _buildPassengerStep(
                        vehicle,
                        draftState,
                        draftNotifier,
                      ),
                      _ => const SizedBox.shrink(),
                    },
                  ),
                ),

                // Bottom Action Bar
                _buildBottomActionBar(draftState, draftNotifier),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Vehicle Summary & Identity Header
  Widget _buildVehicleHeader(VehicleDetails vehicle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.secondarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.directions_car_filled_rounded,
              color: AppColors.primaryBurgundy,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${vehicle.make} ${vehicle.model}',
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.primaryBurgundy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.champagneGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Vehicle ID: ${vehicle.id}',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.warmGold,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${vehicle.vehicleClass} • ${CurrencyFormatter.formatPaise(vehicle.pricing.basePriceCents)} / ${vehicle.pricing.billingUnit}',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Stepper showing current progress across 4 sections
  Widget _buildStepIndicator(int currentStep) {
    final steps = ['Ceremony', 'Date/Time', 'Route', 'Host'];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isCompleted = currentStep > index;
          final isCurrent = currentStep == index;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? AppColors.verifiedEmerald
                                  : (isCurrent
                                        ? AppColors.primaryBurgundy
                                        : AppColors.borderLight),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: isCompleted
                                  ? const Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Colors.white,
                                    )
                                  : Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: isCurrent
                                            ? Colors.white
                                            : AppColors.textSecondaryLight,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              steps[index],
                              style: AppTypography.labelSmall.copyWith(
                                color: isCurrent
                                    ? AppColors.primaryBurgundy
                                    : (isCompleted
                                          ? AppColors.textPrimaryLight
                                          : AppColors.textSecondaryLight),
                                fontWeight: isCurrent
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? AppColors.verifiedEmerald
                              : (isCurrent
                                    ? AppColors.primaryBurgundy
                                    : AppColors.borderLight),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < steps.length - 1) const SizedBox(width: 8),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 0: Event & Ceremony Details
  // ---------------------------------------------------------------------------
  Widget _buildCeremonyStep(
    VehicleDetails vehicle,
    BookingDraftState draftState,
    BookingDraftController controller,
  ) {
    final ceremonies = [
      'Baraat',
      'Vidai',
      'Groom Entry',
      'Bride Entry',
      'Reception',
      'Sangeet',
      'Engagement',
      'Photoshoot',
    ];

    final attires = [
      'Royal Bandhgala & Gold Safa',
      'Classic Black Tuxedo',
      'Traditional Sherwani',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '1. Event & Ceremony Details',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.primaryBurgundy,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose the wedding occasion and ceremonial attire for the chauffeur.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 16),

        ShadiCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Wedding Occasion / Ceremony',
                style: AppTypography.labelMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ceremonies.map((ceremony) {
                  final isSelected = draftState.draft.ceremonyType == ceremony;
                  return ChoiceChip(
                    label: Text(ceremony),
                    selected: isSelected,
                    selectedColor: AppColors.primaryBurgundy,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : AppColors.textPrimaryLight,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      fontSize: 12,
                    ),
                    backgroundColor: AppColors.secondarySurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primaryBurgundy
                            : AppColors.borderLight,
                      ),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        controller.updateCeremony(
                          ceremonyType: ceremony,
                          attire: draftState.draft.ceremonialAttire,
                          instructions: _instructionsController.text,
                        );
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              Text(
                'Chauffeur Ceremonial Attire',
                style: AppTypography.labelMedium,
              ),
              const SizedBox(height: 10),
              Column(
                children: attires.map((attire) {
                  final isSelected =
                      draftState.draft.ceremonialAttire == attire;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.champagneGold.withValues(alpha: 0.1)
                          : Colors.white,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.warmGold
                            : AppColors.borderLight,
                        width: isSelected ? 1.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: InkWell(
                      onTap: () {
                        controller.updateCeremony(
                          ceremonyType: draftState.draft.ceremonyType,
                          attire: attire,
                          instructions: _instructionsController.text,
                        );
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: isSelected
                                  ? AppColors.primaryBurgundy
                                  : AppColors.textSecondaryLight,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                attire,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textPrimaryLight,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              ShadiTextField(
                label: 'Special Ceremonial Instructions (Optional)',
                hint:
                    'e.g., Slow speed during baraat procession, ribbon cutting assistance',
                controller: _instructionsController,
                maxLines: 2,
                onChanged: (val) {
                  controller.updateCeremony(
                    ceremonyType: draftState.draft.ceremonyType,
                    attire: draftState.draft.ceremonialAttire,
                    instructions: val,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1: Date & Time
  // ---------------------------------------------------------------------------
  Widget _buildDateTimeStep(
    VehicleDetails vehicle,
    BookingDraftState draftState,
    BookingDraftController controller,
  ) {
    final durations = [4, 8, 12];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '2. Date & Time Selection',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.primaryBurgundy,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Set your wedding date, pickup time, and expected ceremonial duration.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 16),

        ShadiCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Picker Tile
              Text('Ceremony Date', style: AppTypography.labelMedium),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: draftState.draft.eventDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: AppColors.primaryBurgundy,
                            onPrimary: Colors.white,
                            onSurface: AppColors.textPrimaryLight,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    controller.updateDateTime(
                      date: picked,
                      startTime: draftState.draft.startTime,
                      durationHours: draftState.draft.durationHours,
                    );
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.borderLight),
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        color: AppColors.warmGold,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          DateFormatter.formatCeremonyDate(
                            draftState.draft.eventDate,
                          ),
                          style: AppTypography.titleSmall.copyWith(
                            color: AppColors.textPrimaryLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: AppColors.textSecondaryLight,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Time Picker Tile
              Text('Chauffeur Arrival Time', style: AppTypography.labelMedium),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: draftState.draft.startTime,
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: AppColors.primaryBurgundy,
                            onPrimary: Colors.white,
                            onSurface: AppColors.textPrimaryLight,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    controller.updateDateTime(
                      date: draftState.draft.eventDate,
                      startTime: picked,
                      durationHours: draftState.draft.durationHours,
                    );
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.borderLight),
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        color: AppColors.warmGold,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          draftState.draft.startTime.format(context),
                          style: AppTypography.titleSmall.copyWith(
                            color: AppColors.textPrimaryLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: AppColors.textSecondaryLight,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Duration Selector
              Text('Service Duration', style: AppTypography.labelMedium),
              const SizedBox(height: 10),
              Row(
                children: durations.map((d) {
                  final isSelected = draftState.draft.durationHours == d;
                  final label = switch (d) {
                    4 => '4 Hours\n(Short)',
                    8 => '8 Hours\n(Standard)',
                    12 => '12 Hours\n(Full Day)',
                    _ => '$d Hours',
                  };

                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () {
                          controller.updateDateTime(
                            date: draftState.draft.eventDate,
                            startTime: draftState.draft.startTime,
                            durationHours: d,
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryBurgundy
                                : AppColors.secondarySurface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryBurgundy
                                  : AppColors.borderLight,
                            ),
                          ),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: AppTypography.labelSmall.copyWith(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimaryLight,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Estimated pricing note based on duration
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.secondarySurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Estimated Fare (${draftState.draft.durationHours} hrs):',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatPaise(
                        draftState.draft.estimatedTotalPaise,
                      ),
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.primaryBurgundy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2: Pickup & Destination
  // ---------------------------------------------------------------------------
  Widget _buildLocationsStep(
    BookingDraftState draftState,
    BookingDraftController controller,
  ) {
    final cities = ['Delhi NCR', 'Jaipur', 'Udaipur', 'Mumbai'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '3. Pickup & Destination',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.primaryBurgundy,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Specify the pickup point, ceremony venue, and entrance instructions.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 16),

        ShadiCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Event City', style: AppTypography.labelMedium),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: draftState.draft.city,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(
                    Icons.location_city_rounded,
                    color: AppColors.warmGold,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderLight),
                  ),
                ),
                items: cities
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    controller.updateLocations(
                      city: val,
                      pickupAddress: _pickupController.text,
                      destinationAddress: _destinationController.text,
                      venueName: _venueNameController.text,
                      landmark: _landmarkController.text,
                    );
                  }
                },
              ),
              const SizedBox(height: 16),

              ShadiTextField(
                label: 'Pickup Address / Hotel / Residence',
                hint: 'e.g., The Oberoi, Dr Zakir Hussain Marg',
                prefixIcon: const Icon(
                  Icons.my_location_rounded,
                  color: AppColors.warmGold,
                ),
                controller: _pickupController,
                onChanged: (val) {
                  controller.updateLocations(
                    city: draftState.draft.city,
                    pickupAddress: val,
                    destinationAddress: _destinationController.text,
                    venueName: _venueNameController.text,
                    landmark: _landmarkController.text,
                  );
                },
              ),
              const SizedBox(height: 16),

              ShadiTextField(
                label: 'Destination / Ceremony Venue Address',
                hint: 'e.g., Grand Imperial Banquets, MG Road',
                prefixIcon: const Icon(
                  Icons.pin_drop_rounded,
                  color: AppColors.warmGold,
                ),
                controller: _destinationController,
                onChanged: (val) {
                  controller.updateLocations(
                    city: draftState.draft.city,
                    pickupAddress: _pickupController.text,
                    destinationAddress: val,
                    venueName: _venueNameController.text,
                    landmark: _landmarkController.text,
                  );
                },
              ),
              const SizedBox(height: 16),

              ShadiTextField(
                label: 'Ceremony Venue / Banquet Name',
                hint: 'e.g., Grand Imperial Ballroom',
                prefixIcon: const Icon(
                  Icons.celebration_rounded,
                  color: AppColors.warmGold,
                ),
                controller: _venueNameController,
                onChanged: (val) {
                  controller.updateLocations(
                    city: draftState.draft.city,
                    pickupAddress: _pickupController.text,
                    destinationAddress: _destinationController.text,
                    venueName: val,
                    landmark: _landmarkController.text,
                  );
                },
              ),
              const SizedBox(height: 16),

              ShadiTextField(
                label: 'Landmark or Gate Entry Instructions (Optional)',
                hint: 'e.g., Gate No. 2 VIP Entrance, near North Lawn',
                controller: _landmarkController,
                onChanged: (val) {
                  controller.updateLocations(
                    city: draftState.draft.city,
                    pickupAddress: _pickupController.text,
                    destinationAddress: _destinationController.text,
                    venueName: _venueNameController.text,
                    landmark: val,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3: Passenger & Host Details
  // ---------------------------------------------------------------------------
  Widget _buildPassengerStep(
    VehicleDetails vehicle,
    BookingDraftState draftState,
    BookingDraftController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '4. Passenger & Host Details',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.primaryBurgundy,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Provide the primary wedding coordinator or host contact information.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 16),

        ShadiCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShadiTextField(
                label: 'Primary Host / Contact Name',
                hint: 'e.g., Rajesh Sharma',
                prefixIcon: const Icon(
                  Icons.person_rounded,
                  color: AppColors.warmGold,
                ),
                controller: _contactNameController,
                onChanged: (val) {
                  controller.updatePassengerDetails(
                    contactName: val,
                    contactPhone: _contactPhoneController.text,
                    alternatePhone: _altPhoneController.text,
                    passengerCount: draftState.draft.passengerCount,
                  );
                },
              ),
              const SizedBox(height: 16),

              ShadiTextField(
                label: 'Mobile Number (10 Digits)',
                hint: 'e.g., 9876543210',
                keyboardType: TextInputType.phone,
                prefixIcon: const Icon(
                  Icons.phone_rounded,
                  color: AppColors.warmGold,
                ),
                controller: _contactPhoneController,
                onChanged: (val) {
                  controller.updatePassengerDetails(
                    contactName: _contactNameController.text,
                    contactPhone: val,
                    alternatePhone: _altPhoneController.text,
                    passengerCount: draftState.draft.passengerCount,
                  );
                },
              ),
              const SizedBox(height: 16),

              ShadiTextField(
                label: 'Alternate Family Coordinator Phone (Optional)',
                hint: 'e.g., 9123456780',
                keyboardType: TextInputType.phone,
                prefixIcon: const Icon(
                  Icons.phone_iphone_rounded,
                  color: AppColors.warmGold,
                ),
                controller: _altPhoneController,
                onChanged: (val) {
                  controller.updatePassengerDetails(
                    contactName: _contactNameController.text,
                    contactPhone: _contactPhoneController.text,
                    alternatePhone: val,
                    passengerCount: draftState.draft.passengerCount,
                  );
                },
              ),
              const SizedBox(height: 20),

              Text('Number of Passengers', style: AppTypography.labelMedium),
              const SizedBox(height: 10),
              Row(
                children: List.generate(vehicle.seatingCapacity, (index) {
                  final count = index + 1;
                  final isSelected = draftState.draft.passengerCount == count;

                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () {
                          controller.updatePassengerDetails(
                            contactName: _contactNameController.text,
                            contactPhone: _contactPhoneController.text,
                            alternatePhone: _altPhoneController.text,
                            passengerCount: count,
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryBurgundy
                                : AppColors.secondarySurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryBurgundy
                                  : AppColors.borderLight,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$count',
                              style: AppTypography.titleSmall.copyWith(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textPrimaryLight,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom Action Bar (Back / Continue)
  // ---------------------------------------------------------------------------
  Widget _buildBottomActionBar(
    BookingDraftState draftState,
    BookingDraftController controller,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          if (draftState.activeStep > 0) ...[
            Expanded(
              flex: 1,
              child: ShadiSecondaryButton(
                text: 'Back',
                onPressed: () => controller.previousStep(),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: ShadiPrimaryButton(
              text: draftState.activeStep == 3 ? 'Save & Continue' : 'Continue',
              isLoading: draftState.isLoading,
              onPressed: () {
                if (draftState.activeStep < 3) {
                  controller.nextStep();
                } else {
                  controller.submitDraft();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
