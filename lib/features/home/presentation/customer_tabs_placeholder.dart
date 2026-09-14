import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/shadi_empty_state.dart';

class CustomerSearchPlaceholder extends StatelessWidget {
  const CustomerSearchPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Vehicles')),
      body: const ShadiEmptyState(
        icon: Icons.search_rounded,
        title: 'Find Your Royal Ride',
        description:
            'Search for premium vehicles and verified chauffeurs across Delhi NCR.',
      ),
    );
  }
}

class CustomerBookingsPlaceholder extends StatelessWidget {
  const CustomerBookingsPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Bookings')),
      body: const ShadiEmptyState(
        icon: Icons.calendar_today_rounded,
        title: 'No Upcoming Bookings',
        description: 'Your ceremonial journeys will appear here once booked.',
      ),
    );
  }
}

class CustomerMessagesPlaceholder extends StatelessWidget {
  const CustomerMessagesPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: const ShadiEmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'No Messages Yet',
        description: 'Chat with your chauffeurs and support team here.',
      ),
    );
  }
}

class CustomerProfilePlaceholder extends StatelessWidget {
  const CustomerProfilePlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: Center(
        child: Text(
          'Profile Management Under Development',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.textSecondaryLight,
          ),
        ),
      ),
    );
  }
}
