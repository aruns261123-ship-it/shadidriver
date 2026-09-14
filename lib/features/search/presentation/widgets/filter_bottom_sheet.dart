import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadidriver/core/theme/app_colors.dart';
import 'package:shadidriver/core/theme/app_typography.dart';
import 'package:shadidriver/core/widgets/shadi_primary_button.dart';
import 'package:shadidriver/features/search/presentation/controllers/search_controller.dart';
import 'package:shadidriver/features/search/domain/entities/search_query.dart';

class FilterBottomSheet extends ConsumerStatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  ConsumerState<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<FilterBottomSheet> {
  late VehicleSearchQuery _localQuery;

  @override
  void initState() {
    super.initState();
    _localQuery = ref.read(searchControllerProvider).query;
  }

  void _applyFilters() {
    ref.read(searchControllerProvider.notifier).updateQuery(_localQuery);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filters',
                style: AppTypography.displaySmall.copyWith(fontSize: 20),
              ),
              TextButton(
                onPressed: () =>
                    setState(() => _localQuery = const VehicleSearchQuery()),
                child: const Text('Clear All'),
              ),
            ],
          ),
          const Divider(),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCategoryFilter(),
                  const SizedBox(height: 24),
                  _buildPriceFilter(),
                  const SizedBox(height: 24),
                  _buildVerificationFilter(),
                  const SizedBox(height: 24),
                  _buildTransmissionFilter(),
                  const SizedBox(height: 24),
                  _buildSeatingFilter(),
                  const SizedBox(height: 24),
                  _buildRatingFilter(),
                  const SizedBox(height: 24),
                  _buildAvailabilityFilter(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          ShadiPrimaryButton(text: 'Apply Filters', onPressed: _applyFilters),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final categories = [
      'Luxury Sedan',
      'Premium Sedan',
      'SUV',
      'Vintage',
      'Urbania / Van',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vehicle Category', style: AppTypography.titleSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: categories.map((cat) {
            final isSelected =
                _localQuery.vehicleCategories?.contains(cat) ?? false;
            return FilterChip(
              selected: isSelected,
              label: Text(cat),
              onSelected: (selected) {
                final current = List<String>.from(
                  _localQuery.vehicleCategories ?? [],
                );
                if (selected) {
                  current.add(cat);
                } else {
                  current.remove(cat);
                }
                setState(
                  () => _localQuery = _localQuery.copyWith(
                    vehicleCategories: current,
                  ),
                );
              },
              selectedColor: AppColors.primaryBurgundy.withValues(alpha: 0.1),
              checkmarkColor: AppColors.primaryBurgundy,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPriceFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Daily Budget Range', style: AppTypography.titleSmall),
        const SizedBox(height: 12),
        RangeSlider(
          values: RangeValues(
            (_localQuery.minPriceCents ?? 0) / 100000.0,
            (_localQuery.maxPriceCents ?? 10000000) / 100000.0,
          ),
          min: 0,
          max: 100,
          divisions: 20,
          labels: RangeLabels(
            '₹${((_localQuery.minPriceCents ?? 0) / 100).round()}',
            '₹${((_localQuery.maxPriceCents ?? 10000000) / 100).round()}',
          ),
          activeColor: AppColors.primaryBurgundy,
          onChanged: (values) {
            setState(() {
              _localQuery = _localQuery.copyWith(
                minPriceCents: (values.start * 100000).round(),
                maxPriceCents: (values.end * 100000).round(),
              );
            });
          },
        ),
      ],
    );
  }

  Widget _buildVerificationFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Verification', style: AppTypography.titleSmall),
        SwitchListTile(
          title: const Text('Verified Chauffeurs Only'),
          value: _localQuery.verifiedChauffeurOnly,
          activeColor: AppColors.primaryBurgundy,
          onChanged: (val) => setState(
            () =>
                _localQuery = _localQuery.copyWith(verifiedChauffeurOnly: val),
          ),
        ),
        SwitchListTile(
          title: const Text('Verified Vehicles Only'),
          value: _localQuery.verifiedVehicleOnly,
          activeColor: AppColors.primaryBurgundy,
          onChanged: (val) => setState(
            () => _localQuery = _localQuery.copyWith(verifiedVehicleOnly: val),
          ),
        ),
      ],
    );
  }

  Widget _buildTransmissionFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Transmission', style: AppTypography.titleSmall),
        const SizedBox(height: 12),
        Row(
          children: [
            ChoiceChip(
              label: const Text('Automatic'),
              selected: _localQuery.transmission == 'AUTOMATIC',
              onSelected: (val) => setState(
                () => _localQuery = _localQuery.copyWith(
                  transmission: val ? 'AUTOMATIC' : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Manual'),
              selected: _localQuery.transmission == 'MANUAL',
              onSelected: (val) => setState(
                () => _localQuery = _localQuery.copyWith(
                  transmission: val ? 'MANUAL' : null,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvailabilityFilter() {
    return SwitchListTile(
      title: const Text('Available Now'),
      subtitle: const Text(
        'Show only nearby drivers ready for immediate dispatch',
      ),
      value: _localQuery.availableNow,
      activeColor: AppColors.urgentSaffron,
      onChanged: (val) =>
          setState(() => _localQuery = _localQuery.copyWith(availableNow: val)),
    );
  }

  Widget _buildSeatingFilter() {
    final capacities = [2, 4, 5, 7, 14];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Seating Capacity', style: AppTypography.titleSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: capacities.map((cap) {
            final isSelected =
                _localQuery.seatingCapacities?.contains(cap) ?? false;
            return FilterChip(
              selected: isSelected,
              label: Text('$cap+'),
              onSelected: (selected) {
                final current = List<int>.from(
                  _localQuery.seatingCapacities ?? [],
                );
                if (selected) {
                  current.add(cap);
                } else {
                  current.remove(cap);
                }
                setState(
                  () => _localQuery = _localQuery.copyWith(
                    seatingCapacities: current,
                  ),
                );
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRatingFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Minimum Rating', style: AppTypography.titleSmall),
        const SizedBox(height: 12),
        Row(
          children: [4.0, 4.5, 4.8].map((rating) {
            final isSelected = _localQuery.minRating == rating;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('$rating+ ⭐'),
                selected: isSelected,
                onSelected: (val) => setState(
                  () => _localQuery = _localQuery.copyWith(
                    minRating: val ? rating : null,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
