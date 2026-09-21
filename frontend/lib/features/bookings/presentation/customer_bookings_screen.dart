import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers/app_providers.dart';
import '../../../app/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/shadi_card.dart';
import '../../../core/widgets/shadi_empty_state.dart';
import '../../../core/widgets/shadi_loading_indicator.dart';
import '../../../core/widgets/shadi_primary_button.dart';
import '../domain/entities/booking_summary.dart';

/// Provider for customer's bookings list
final customerBookingsProvider =
    FutureProvider.autoDispose<List<BookingSummary>>((ref) async {
      final repo = ref.watch(bookingRepositoryProvider);
      final result = await repo.getMyBookings();
      if (result.isSuccess) {
        return result.dataOrNull!;
      }
      return [];
    });

/// Production-ready Customer Bookings tab screen with tabs, status badges,
/// timing details, and ceremonial journey cards.
class CustomerBookingsScreen extends ConsumerStatefulWidget {
  const CustomerBookingsScreen({super.key});

  @override
  ConsumerState<CustomerBookingsScreen> createState() =>
      _CustomerBookingsScreenState();
}

class _CustomerBookingsScreenState extends ConsumerState<CustomerBookingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(customerBookingsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'My Ceremonial Journeys',
          style: AppTypography.displaySmall.copyWith(
            color: AppColors.primaryBurgundy,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryBurgundy,
          unselectedLabelColor: AppColors.textSecondaryLight,
          indicatorColor: AppColors.primaryBurgundy,
          indicatorWeight: 3,
          labelStyle: AppTypography.labelMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: AppTypography.labelMedium,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Completed'),
            Tab(text: 'All'),
          ],
        ),
      ),
      body: bookingsAsync.when(
        loading: () => const Center(child: ShadiLoadingIndicator()),
        error: (err, _) => Center(
          child: ShadiEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Unable to Load Bookings',
            description: err.toString(),
          ),
        ),
        data: (bookings) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildBookingsList(
                bookings
                    .where(
                      (b) => b.status != 'COMPLETED' && b.status != 'CANCELLED',
                    )
                    .toList(),
                emptyTitle: 'No Upcoming Journeys',
                emptyDesc:
                    'Book luxury transport for your wedding ceremonies with royal chauffeurs.',
              ),
              _buildBookingsList(
                bookings.where((b) => b.status == 'COMPLETED').toList(),
                emptyTitle: 'No Past Ceremonies',
                emptyDesc:
                    'Completed ceremonial rides will be catalogued here.',
              ),
              _buildBookingsList(
                bookings,
                emptyTitle: 'No Bookings Found',
                emptyDesc:
                    'Your reservation requests will appear here once booked.',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBookingsList(
    List<BookingSummary> list, {
    required String emptyTitle,
    required String emptyDesc,
  }) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShadiEmptyState(
                icon: Icons.calendar_today_rounded,
                title: emptyTitle,
                description: emptyDesc,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 220,
                child: ShadiPrimaryButton(
                  text: 'Explore Fleet',
                  onPressed: () => context.go(RoutePaths.customerSearch),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(customerBookingsProvider),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final item = list[index];
          return _buildBookingCard(item);
        },
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final w = weekdays[dt.weekday - 1];
    final m = months[dt.month - 1];
    final hr = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$w, ${dt.day} $m ${dt.year} • $hr:$min $period';
  }

  String _formatTimeOnly(DateTime dt) {
    final hr = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hr:$min $period';
  }

  Widget _buildBookingCard(BookingSummary booking) {
    final startStr = _formatDateTime(booking.eventStartTime);
    final endStr = _formatTimeOnly(booking.eventEndTime);

    return ShadiCard(
      padding: const EdgeInsets.all(16),
      onTap: () => context.push(
        RoutePaths.customerBookingDetailPath(booking.id),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Reference & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.confirmation_number_outlined,
                    size: 16,
                    color: AppColors.warmGold,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    booking.reference,
                    style: AppTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryBurgundy,
                    ),
                  ),
                ],
              ),
              _buildStatusBadge(booking.status),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 12),

          // Ceremony & Vehicle Details
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.secondarySurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: const Icon(
                  Icons.celebration_rounded,
                  color: AppColors.primaryBurgundy,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${booking.serviceCategory} Ceremony',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    if (booking.vehicleName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        booking.vehicleName,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.primaryBurgundy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.formatPaise(booking.totalAmountCents),
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.primaryBurgundy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Token: ${CurrencyFormatter.formatPaise(booking.advanceTokenCents)}',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Schedule & Duration
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.secondarySurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: AppColors.warmGold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$startStr → $endStr (${booking.formattedDuration})',
                    style: AppTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                ),
                if (booking.isOvernight)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBurgundy.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '🌙 Overnight',
                      style: AppTypography.labelSmall.copyWith(
                        fontSize: 10,
                        color: AppColors.primaryBurgundy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Route: Pickup & Destination
          Row(
            children: [
              const Icon(
                Icons.my_location_rounded,
                size: 14,
                color: AppColors.warmGold,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  booking.pickupAddress,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (booking.destinationAddress.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.pin_drop_rounded,
                  size: 14,
                  color: AppColors.primaryBurgundy,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    booking.destinationAddress,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (booking.routeDistanceKm != null)
                  Text(
                    '• ${booking.routeDistanceKm!.toStringAsFixed(1)} km',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.warmGold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
          if (booking.chauffeurName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.person_pin_rounded,
                  size: 14,
                  color: AppColors.champagneGold,
                ),
                const SizedBox(width: 8),
                Text(
                  'Assigned Chauffeur: ${booking.chauffeurName}',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color text;
    String label;

    switch (status.toUpperCase()) {
      case 'REQUESTED':
        bg = const Color(0xFFFFF3CD);
        text = const Color(0xFF856404);
        label = 'Awaiting Confirmation';
        break;
      case 'CONFIRMED':
      case 'DRIVER_ACCEPTED':
        bg = const Color(0xFFD4EDDA);
        text = const Color(0xFF155724);
        label = 'Confirmed';
        break;
      case 'COMPLETED':
        bg = const Color(0xFFE2E3E5);
        text = const Color(0xFF383D41);
        label = 'Completed';
        break;
      case 'CANCELLED':
        bg = const Color(0xFFF8D7DA);
        text = const Color(0xFF721C24);
        label = 'Cancelled';
        break;
      default:
        bg = AppColors.secondarySurface;
        text = AppColors.textPrimaryLight;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: text,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
