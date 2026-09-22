import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers/app_providers.dart';
import '../../../app/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/shadi_empty_state.dart';
import '../../../core/widgets/shadi_loading_indicator.dart';
import '../../../core/widgets/shadi_primary_button.dart';
import '../../services/domain/entities/service_category.dart';
import 'controllers/urgent_dispatch_controller.dart';

/// Customer SOS screen: requests an urgent verified chauffeur from the
/// operations pool when a ceremony needs a car right now.
class UrgentDispatchSosScreen extends ConsumerStatefulWidget {
  const UrgentDispatchSosScreen({super.key});

  @override
  ConsumerState<UrgentDispatchSosScreen> createState() =>
      _UrgentDispatchSosScreenState();
}

class _UrgentDispatchSosScreenState
    extends ConsumerState<UrgentDispatchSosScreen> {
  ServiceCategory? _selectedCategory;
  final _addressController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(serviceCategoriesProvider);
    final state = ref.watch(urgentDispatchControllerProvider);

    // Success: show the confirmation card.
    if (state.isSuccess) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'Urgent Dispatch',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.primaryBurgundy,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.urgentSaffron.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: AppColors.urgentSaffron,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Dispatch Request Sent',
                  style: AppTypography.titleLarge.copyWith(
                    color: AppColors.primaryBurgundy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Operations is radioing the nearest verified chauffeur for your ${_selectedCategory?.name ?? 'ceremony'} at:\n\n${_addressController.text}',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.urgentSaffron.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    'Dispatch ID: ${state.dispatchId}',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.urgentSaffron,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                ShadiPrimaryButton(
                  text: 'Back to Home',
                  onPressed: () => context.go(RoutePaths.customerHome),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Urgent Dispatch',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.primaryBurgundy,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.urgentSaffron.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.urgentSaffron.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    color: AppColors.urgentSaffron,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'A verified chauffeur will be urgently dispatched to your ceremony location. Please ensure the pickup details are accurate.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 1. Service category picker
            Text(
              'Ceremony Type',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 8),
            categoriesAsync.when(
              loading: () => const ShadiLoadingIndicator(size: 24),
              error: (err, _) => ShadiEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Failed to load ceremony types',
                description: 'Pull down to retry after re-entering the screen.',
              ),
              data: (categories) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories
                    .map(
                      (c) => ChoiceChip(
                        label: Text(c.name),
                        selected: _selectedCategory == c,
                        selectedColor: AppColors.urgentSaffron.withValues(
                          alpha: 0.2,
                        ),
                        labelStyle: AppTypography.labelLarge.copyWith(
                          color: _selectedCategory == c
                              ? AppColors.urgentSaffron
                              : AppColors.textSecondaryLight,
                          fontWeight: _selectedCategory == c
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                        onSelected: (_) =>
                            setState(() => _selectedCategory = c),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 20),

            // 2. Pickup address
            Text(
              'Pickup Location',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _addressController,
              maxLines: 2,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: 'Venue name / full address for the chauffeur',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.location_on_outlined),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Please enter the pickup address'
                  : null,
            ),
            const SizedBox(height: 28),

            // 3. Submit
            ShadiPrimaryButton(
              key: const Key('submit_urgent_dispatch_btn'),
              text: 'Dispatch Urgent Chauffeur',
              isLoading: state.isSubmitting,
              onPressed: state.isSubmitting || _selectedCategory == null
                  ? null
                  : () {
                      if (!_formKey.currentState!.validate()) return;
                      HapticFeedback.heavyImpact();
                      ref
                          .read(urgentDispatchControllerProvider.notifier)
                          .submitRequest(
                            category: _selectedCategory!,
                            address: _addressController.text.trim(),
                          );
                    },
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
