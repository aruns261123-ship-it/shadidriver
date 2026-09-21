import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/route_paths.dart';
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
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Profile Management Under Development',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                key: const Key('view_customer_profile_btn'),
                onPressed: () => context.go(RoutePaths.customerProfile),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBurgundy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.person_rounded),
                label: const Text('Open Account Center'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
