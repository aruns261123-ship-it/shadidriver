import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/providers/app_providers.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/vehicle_reference.dart';
import '../../../../core/widgets/shadi_card.dart';
import '../../../../core/widgets/shadi_error_view.dart';
import '../../../../core/widgets/shadi_loading_indicator.dart';
import '../../../../core/widgets/shadi_primary_button.dart';
import '../../../../core/widgets/shadi_secondary_button.dart';
import '../../../../core/widgets/shadi_text_field.dart';
import '../domain/entities/booking_draft.dart';
import '../domain/entities/search_handoff.dart';
import '../../vehicles/domain/entities/vehicle_details.dart';
import '../../vehicles/presentation/controllers/vehicle_details_controller.dart';
import 'controllers/booking_draft_controller.dart';
import 'controllers/booking_review_controller.dart';
import 'widgets/booking_draft_summary_card.dart';

/// Milestone 4A - Customer Booking Entry & Event Details Screen.
///
/// Implements the flow:
/// Vehicle Details -> Book Now -> Booking Entry -> Event/Ceremony -> Date/Time -> Pickup/Destination -> Passenger Details -> Continue
class BookingEntryScreen extends ConsumerStatefulWidget {
  final String vehicleId;
  final String? draftId;

  /// Search intent (destination, date, occasion) prefilled into the draft.
  final SearchHandoff? searchHandoff;

  const BookingEntryScreen({
    super.key,
    required this.vehicleId,
    this.draftId,
    this.searchHandoff,
  });

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
    if (!_initializedWithDefaults && !draftState.isLoadingDraft) {
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

  void _resetControllers(BookingDraft draft) {
    _instructionsController.text = draft.specialInstructions;
    _pickupController.text = draft.pickupAddress;
    _destinationController.text = draft.destinationAddress;
    _venueNameController.text = draft.venueName;
    _landmarkController.text = draft.landmark;
    _contactNameController.text = draft.primaryContactName;
    _contactPhoneController.text = draft.primaryContactPhone;
    _altPhoneController.text = draft.alternateContactPhone ?? '';
  }

  Future<void> _handleBack(
    BookingDraftState draftState,
    BookingDraftController controller,
  ) async {
    if (draftState.hasUnsavedChanges) {
      final shouldDiscard = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            'Discard unsaved changes?',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.primaryBurgundy,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'You have unsaved changes to this reservation draft. Do you want to discard them?',
            style: AppTypography.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(
                'Keep Editing',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.primaryBurgundy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: Text(
                'Discard Changes',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.errorRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

      if (shouldDiscard == true) {
        controller.resetUnsavedChanges();
        if (draftState.originalDraft != null) {
          _resetControllers(draftState.originalDraft!);
        }
        if (mounted && context.canPop()) {
          context.pop();
        }
      }
    } else {
      if (context.canPop()) {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleAsync = ref.watch(vehicleDetailsProvider(widget.vehicleId));

    return vehicleAsync.when(
      loading: () => Scaffold(
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
        body: const ShadiLoadingIndicator(
          message: 'Loading vehicle booking configuration...',
        ),
      ),
      error: (err, _) => Scaffold(
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
        body: ShadiErrorView(
          message: 'Unable to initialize booking draft. Vehicle not found.',
          onRetry: () => ref.refresh(vehicleDetailsProvider(widget.vehicleId)),
        ),
      ),
      data: (vehicle) {
        final params = BookingDraftParams(
          vehicle: vehicle,
          draftId: widget.draftId,
          searchHandoff: widget.searchHandoff,
        );
        final draftState = ref.watch(bookingDraftControllerProvider(params));
        final draftNotifier = ref.read(
          bookingDraftControllerProvider(params).notifier,
        );

        _syncControllersWithDraft(draftState);

        if (draftState.isLoadingDraft) {
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
                'Edit Reservation',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.primaryBurgundy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              centerTitle: true,
            ),
            body: const Center(
              child: ShadiLoadingIndicator(
                message: 'Loading ceremonial reservation draft...',
              ),
            ),
          );
        }

        if (!draftState.isEditMode &&
            draftState.isSaved &&
            draftState.savedDraft != null) {
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
                onPressed: () => context.go(RoutePaths.customerHome),
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
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: BookingDraftSummaryCard(
                draft: draftState.savedDraft!,
                onDismiss: () => context.go(RoutePaths.customerHome),
                onReview: () => context.pushReplacement(
                  RoutePaths.customerBookingReviewPath(
                    draftState.savedDraft!.id,
                  ),
                ),
              ),
            ),
          );
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              _handleBack(draftState, draftNotifier);
            }
          },
          child: Scaffold(
            backgroundColor: AppColors.backgroundLight,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.primaryBurgundy,
                ),
                onPressed: () => _handleBack(draftState, draftNotifier),
              ),
              title: Text(
                draftState.isEditMode
                    ? 'Edit Reservation'
                    : 'Booking Experience',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.primaryBurgundy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              centerTitle: true,
            ),
            body: SafeArea(
              child: Column(
                children: [
                  // Top Vehicle & Flow Header
                  _buildVehicleHeader(vehicle, draftState, draftNotifier),

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
            ),
          ),
        );
      },
    );
  }

  /// Vehicle Summary & Identity Header
  Widget _buildVehicleHeader(
    VehicleDetails vehicle,
    BookingDraftState draftState,
    BookingDraftController controller,
  ) {
    final vehicleName = draftState.draft.vehicleName.isNotEmpty
        ? draftState.draft.vehicleName
        : '${vehicle.make} ${vehicle.model}';
    final vehicleClass = draftState.draft.vehicleClass.isNotEmpty
        ? draftState.draft.vehicleClass
        : vehicle.vehicleClass;
    final vehicleId = draftState.draft.vehicleId.isNotEmpty
        ? draftState.draft.vehicleId
        : vehicle.id;

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
                // Both children are flexible: the name ellipsizes first, and
                // the id badge is shortened so a 36-char UUID can never push
                // this row past the screen edge.
                Row(
                  children: [
                    Flexible(
                      flex: 3,
                      child: Text(
                        vehicleName,
                        style: AppTypography.titleSmall.copyWith(
                          color: AppColors.primaryBurgundy,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      flex: 2,
                      child: Tooltip(
                        message: 'Vehicle ID: $vehicleId',
                        child: Semantics(
                          label: 'Vehicle ID $vehicleId',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.champagneGold.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Vehicle ID: ${VehicleReference.shorten(vehicleId)}',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.warmGold,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$vehicleClass • ${CurrencyFormatter.formatPaise(draftState.draft.basePricePaise)} base',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () =>
                _showChangeVehicleDialog(context, controller, vehicleId),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Change',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.primaryBurgundy,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangeVehicleDialog(
    BuildContext context,
    BookingDraftController controller,
    String currentVehicleId,
  ) async {
    final vehicleRepo = ref.read(vehicleRepositoryProvider);
    final availableRes = await vehicleRepo.getAvailableVehicles();
    if (!context.mounted) return;

    final vehicles = availableRes.dataOrNull ?? [];
    if (vehicles.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Ceremonial Vehicle',
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.primaryBurgundy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(bottomSheetCtx).pop(),
                    ),
                  ],
                ),
                const Divider(),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: vehicles.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (ctx, index) {
                      final v = vehicles[index];
                      final isSelected = v.id == currentVehicleId;
                      return ListTile(
                        leading: Icon(
                          Icons.directions_car_filled_rounded,
                          color: isSelected
                              ? AppColors.primaryBurgundy
                              : AppColors.textSecondaryLight,
                        ),
                        title: Text(
                          '${v.make} ${v.model}',
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? AppColors.primaryBurgundy
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        subtitle: Text(
                          '${v.vehicleClass} • ${CurrencyFormatter.formatPaise(v.pricing.basePriceCents)} / ${v.pricing.billingUnit}',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primaryBurgundy,
                              )
                            : null,
                        onTap: () async {
                          Navigator.of(bottomSheetCtx).pop();
                          final detailsRes = await vehicleRepo
                              .getVehicleDetails(v.id);
                          final details = detailsRes.dataOrNull;
                          if (details != null) {
                            controller.updateVehicle(details);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
    final start = draftState.draft.serviceStartDateTime;
    final end = draftState.draft.serviceEndDateTime;
    final isOvernight = draftState.draft.isOvernight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '2. Service Timing & Duration',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.primaryBurgundy,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Specify exact start and end times. Overnight wedding bookings across midnight are fully supported.',
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
              // 1. Service Start
              Text('Service Start', style: AppTypography.labelMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: InkWell(
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: start,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: AppColors.primaryBurgundy,
                                onPrimary: Colors.white,
                                onSurface: AppColors.textPrimaryLight,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (pickedDate != null) {
                          final newStart = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            start.hour,
                            start.minute,
                          );
                          // Adjust end to preserve duration if end is before new start
                          DateTime newEnd = end;
                          if (!newEnd.isAfter(newStart)) {
                            newEnd = newStart.add(
                              Duration(
                                hours: draftState.draft.durationHours > 0
                                    ? draftState.draft.durationHours
                                    : 8,
                              ),
                            );
                          }
                          controller.updateServiceTiming(
                            startDateTime: newStart,
                            endDateTime: newEnd,
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
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
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                DateFormatter.formatCeremonyDate(start),
                                style: AppTypography.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: () async {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: start.hour,
                            minute: start.minute,
                          ),
                        );
                        if (pickedTime != null) {
                          final newStart = DateTime(
                            start.year,
                            start.month,
                            start.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                          DateTime newEnd = end;
                          if (!newEnd.isAfter(newStart)) {
                            newEnd = newStart.add(
                              Duration(
                                hours: draftState.draft.durationHours > 0
                                    ? draftState.draft.durationHours
                                    : 8,
                              ),
                            );
                          }
                          controller.updateServiceTiming(
                            startDateTime: newStart,
                            endDateTime: newEnd,
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
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
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
                                style: AppTypography.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Service End
              Text('Service End', style: AppTypography.labelMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: InkWell(
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: end,
                          firstDate: start,
                          lastDate: start.add(const Duration(days: 30)),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: AppColors.primaryBurgundy,
                                onPrimary: Colors.white,
                                onSurface: AppColors.textPrimaryLight,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (pickedDate != null) {
                          final newEnd = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            end.hour,
                            end.minute,
                          );
                          controller.updateServiceTiming(
                            startDateTime: start,
                            endDateTime: newEnd,
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.borderLight),
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.event_available_rounded,
                              color: AppColors.warmGold,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                DateFormatter.formatCeremonyDate(end),
                                style: AppTypography.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: () async {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: end.hour,
                            minute: end.minute,
                          ),
                        );
                        if (pickedTime != null) {
                          final newEnd = DateTime(
                            end.year,
                            end.month,
                            end.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                          controller.updateServiceTiming(
                            startDateTime: start,
                            endDateTime: newEnd,
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
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
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
                                style: AppTypography.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Calculated Duration & Overnight Badge
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isOvernight
                      ? AppColors.champagneGold.withValues(alpha: 0.15)
                      : AppColors.secondarySurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isOvernight
                        ? AppColors.warmGold
                        : AppColors.borderLight,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isOvernight
                                  ? Icons.nightlight_round
                                  : Icons.schedule_rounded,
                              color: isOvernight
                                  ? AppColors.warmGold
                                  : AppColors.primaryBurgundy,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Calculated Duration:',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.textSecondaryLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          draftState.draft.formattedDuration,
                          style: AppTypography.titleSmall.copyWith(
                            color: AppColors.primaryBurgundy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (isOvernight) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 14,
                            color: AppColors.warmGold,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Overnight ceremonial booking spanning across midnight. Continuous chauffeur standby included.',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.primaryBurgundy,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Quick Ceremonial Timing Presets
              Text('Ceremony Presets', style: AppTypography.labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(
                      Icons.nightlife_rounded,
                      size: 16,
                      color: AppColors.primaryBurgundy,
                    ),
                    label: const Text('Baraat Overnight (8 PM → 7 AM)'),
                    onPressed: () {
                      final s = DateTime(
                        start.year,
                        start.month,
                        start.day,
                        20,
                        0,
                      );
                      final nextDay = s.add(const Duration(days: 1));
                      final e = DateTime(
                        nextDay.year,
                        nextDay.month,
                        nextDay.day,
                        7,
                        0,
                      );
                      controller.updateServiceTiming(
                        startDateTime: s,
                        endDateTime: e,
                      );
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(
                      Icons.celebration_rounded,
                      size: 16,
                      color: AppColors.primaryBurgundy,
                    ),
                    label: const Text('Evening Reception (4 PM → 12 AM)'),
                    onPressed: () {
                      final s = DateTime(
                        start.year,
                        start.month,
                        start.day,
                        16,
                        0,
                      );
                      final e = DateTime(
                        start.year,
                        start.month,
                        start.day,
                        24,
                        0,
                      );
                      controller.updateServiceTiming(
                        startDateTime: s,
                        endDateTime: e,
                      );
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(
                      Icons.wb_sunny_rounded,
                      size: 16,
                      color: AppColors.primaryBurgundy,
                    ),
                    label: const Text('Day Wedding (8 AM → 6 PM)'),
                    onPressed: () {
                      final s = DateTime(
                        start.year,
                        start.month,
                        start.day,
                        8,
                        0,
                      );
                      final e = DateTime(
                        start.year,
                        start.month,
                        start.day,
                        18,
                        0,
                      );
                      controller.updateServiceTiming(
                        startDateTime: s,
                        endDateTime: e,
                      );
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(
                      Icons.timelapse_rounded,
                      size: 16,
                      color: AppColors.primaryBurgundy,
                    ),
                    label: const Text('Short Ceremony (4 Hours)'),
                    onPressed: () {
                      final s = DateTime(
                        start.year,
                        start.month,
                        start.day,
                        16,
                        0,
                      );
                      final e = s.add(const Duration(hours: 4));
                      controller.updateServiceTiming(
                        startDateTime: s,
                        endDateTime: e,
                      );
                    },
                  ),
                ],
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
              if (draftState.draft.routeDistanceKm != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.champagneGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.warmGold.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.route_rounded,
                        color: AppColors.warmGold,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estimated Route Distance',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                            Text(
                              '${draftState.draft.routeDistanceKm!.toStringAsFixed(1)} km (approximate ceremony route)',
                              style: AppTypography.bodySmall.copyWith(
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
    final isLastStep = draftState.activeStep == 3;
    final buttonText = draftState.isEditMode
        ? (isLastStep ? 'Save Changes' : 'Continue')
        : (isLastStep ? 'Save & Continue' : 'Continue');

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
              text: buttonText,
              isLoading: draftState.isLoading,
              onPressed: draftState.isLoading
                  ? null
                  : () async {
                      if (draftState.activeStep < 3) {
                        controller.nextStep();
                      } else {
                        final success = await controller.submitDraft();
                        if (success && mounted) {
                          if (draftState.isEditMode) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Booking draft updated'),
                                backgroundColor: AppColors.primaryBurgundy,
                                duration: Duration(seconds: 2),
                              ),
                            );
                            if (widget.draftId != null) {
                              ref.invalidate(
                                bookingReviewControllerProvider(
                                  widget.draftId!,
                                ),
                              );
                            }
                            context.pop();
                          }
                        }
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }
}
