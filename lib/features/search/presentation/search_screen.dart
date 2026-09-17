import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadidriver/app/router/route_paths.dart';
import 'package:shadidriver/core/theme/app_colors.dart';
import 'package:shadidriver/core/theme/app_typography.dart';
import 'package:shadidriver/core/widgets/shadi_primary_button.dart';
import 'package:shadidriver/core/widgets/shadi_text_field.dart';
import 'controllers/search_controller.dart';
import '../domain/entities/search_query.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late TextEditingController _pickupController;
  late TextEditingController _destinationController;
  DateTime? _selectedDate;
  String? _selectedOccasion;
  int _passengers = 4;

  @override
  void initState() {
    super.initState();
    final currentQuery = ref.read(searchControllerProvider).query;
    _pickupController = TextEditingController(
      text: currentQuery.pickupLocation,
    );
    _destinationController = TextEditingController(
      text: currentQuery.destination,
    );
    _selectedDate = currentQuery.eventDate;
    _selectedOccasion = currentQuery.occasionId;
    _passengers = currentQuery.passengerCount ?? 4;
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void _onSearch() {
    ref.read(searchControllerProvider.notifier).updateQuery(
          VehicleSearchQuery(
            pickupLocation: _pickupController.text,
            destination: _destinationController.text,
            eventDate: _selectedDate,
            occasionId: _selectedOccasion,
            passengerCount: _passengers,
          ),
        );
    context.push(RoutePaths.customerSearchResults);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          'Find Your Royal Ride',
          style: AppTypography.displaySmall.copyWith(
            color: AppColors.primaryBurgundy,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShadiTextField(
              label: 'Pickup Location',
              hint: 'Enter pickup address',
              controller: _pickupController,
              prefixIcon: const Icon(Icons.location_on_rounded),
            ),
            const SizedBox(height: 20),
            ShadiTextField(
              label: 'Destination',
              hint: 'Enter venue or destination',
              controller: _destinationController,
              prefixIcon: const Icon(Icons.map_rounded),
            ),
            const SizedBox(height: 20),
            _buildDatePicker(context),
            const SizedBox(height: 20),
            _buildOccasionPicker(),
            const SizedBox(height: 20),
            _buildPassengerCounter(),
            const SizedBox(height: 40),
            ShadiPrimaryButton(
              text: 'Search Chauffeurs',
              onPressed: _onSearch,
              icon: Icons.search_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Event Date', style: AppTypography.labelSmall),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now().add(const Duration(days: 7)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date != null) setState(() => _selectedDate = date);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  color: AppColors.champagneGold,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  _selectedDate == null
                      ? 'Select Date'
                      : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                  style: AppTypography.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOccasionPicker() {
    final occasions = [
      'Baraat',
      'Vidai',
      'Bride Entry',
      'Groom Entry',
      'Guest Transport',
      'Photoshoot',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ceremony / Occasion', style: AppTypography.labelSmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedOccasion,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(
              Icons.celebration_rounded,
              color: AppColors.champagneGold,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
          ),
          items: occasions
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (val) => setState(() => _selectedOccasion = val),
          hint: const Text('Select Occasion'),
        ),
      ],
    );
  }

  Widget _buildPassengerCounter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Passengers', style: AppTypography.labelSmall),
            Text(
              'Number of guests to carry',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiaryLight,
              ),
            ),
          ],
        ),
        Row(
          children: [
            _buildCounterButton(Icons.remove, () {
              if (_passengers > 1) setState(() => _passengers--);
            }),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('$_passengers', style: AppTypography.titleLarge),
            ),
            _buildCounterButton(Icons.add, () {
              if (_passengers < 50) setState(() => _passengers++);
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildCounterButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.secondarySurface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: AppColors.primaryBurgundy),
      ),
    );
  }
}
