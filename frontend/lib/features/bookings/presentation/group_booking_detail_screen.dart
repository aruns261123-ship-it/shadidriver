import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers/app_providers.dart';
import '../../../core/errors/failures.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/shadi_card.dart';
import '../../../core/widgets/shadi_error_view.dart';
import '../../../core/widgets/shadi_loading_indicator.dart';
import '../domain/entities/group_booking.dart';

/// Loads the group booking + full assignment breakdown from the backend.
final groupBookingDetailProvider = FutureProvider.autoDispose
    .family<GroupBooking?, String>((ref, groupBookingId) async {
  final repo = ref.watch(bookingRepositoryProvider);
  final result = await repo.getGroupBooking(groupBookingId);
  if (result.isSuccess) return result.dataOrNull;
  throw result.failureOrNull ?? const UnknownFailure('Group booking not found.');
});

/// Group Booking Detail — ONE parent reference with the full vehicle/
/// chauffeur assignment breakdown. Customers see every unit in their convoy;
/// drivers see only their own assignment (enforced server-side).
class GroupBookingDetailScreen extends ConsumerWidget {
  const GroupBookingDetailScreen({super.key, required this.groupBookingId});

  final String groupBookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(groupBookingDetailProvider(groupBookingId));
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(
          'Group Booking',
          style: AppTypography.titleLarge.copyWith(
            color: AppColors.primaryBurgundy,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: ShadiLoadingIndicator()),
        error: (e, _) => ShadiErrorView(
          message: 'Unable to load group booking: $e',
          onRetry: () =>
              ref.invalidate(groupBookingDetailProvider(groupBookingId)),
        ),
        data: (group) {
          if (group == null) {
            return const ShadiErrorView(message: 'Group booking not found.');
          }
          return _GroupBookingDetailBody(group: group);
        },
      ),
    );
  }
}

class _GroupBookingDetailBody extends StatelessWidget {
  const _GroupBookingDetailBody({required this.group});

  final GroupBooking group;

  String _formatPaise(int paise) {
    final rupees = paise / 100;
    return '₹${rupees.toStringAsFixed(rupees.truncateToDouble() == rupees ? 0 : 2)}';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ShadiCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group.bookingReference,
                style: AppTypography.titleLarge.copyWith(
                  color: AppColors.primaryBurgundy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${group.ceremonyType} • ${group.city}',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textSecondaryLight),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _InfoCell(
                      icon: Icons.directions_car_rounded,
                      label: 'Vehicles',
                      value: '${group.totalVehicles}',
                    ),
                  ),
                  Expanded(
                    child: _InfoCell(
                      icon: Icons.groups_rounded,
                      label: 'Guests',
                      value: '${group.totalPassengers}',
                    ),
                  ),
                  Expanded(
                    child: _InfoCell(
                      icon: Icons.schedule_rounded,
                      label: 'Duration',
                      value: '${group.serviceEndDateTime
                          .difference(group.serviceStartDateTime)
                          .inHours} hrs',
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Text('Itinerary', style: AppTypography.labelLarge),
              const SizedBox(height: 4),
              Text('Pickup: ${group.pickupAddress}',
                  style: AppTypography.bodySmall),
              const SizedBox(height: 2),
              Text('Venue: ${group.destinationAddress}',
                  style: AppTypography.bodySmall),
              const SizedBox(height: 8),
              Text(
                '${group.serviceStartDateTime.day}/${group.serviceStartDateTime.month}/${group.serviceStartDateTime.year} • '
                '${group.serviceStartDateTime.hour.toString().padLeft(2, '0')}:'
                '${group.serviceStartDateTime.minute.toString().padLeft(2, '0')}',
                style: AppTypography.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Vehicle Assignments (${group.assignments.length})',
            style: AppTypography.titleMedium),
        const SizedBox(height: 8),
        for (final assignment in group.assignments)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ShadiCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.softChampagne,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${group.assignments.indexOf(assignment) + 1}',
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.primaryBurgundy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(assignment.vehicleModel,
                            style: AppTypography.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          assignment.chauffeurName != null &&
                                  assignment.chauffeurName!.isNotEmpty
                              ? 'Chauffeur: ${assignment.chauffeurName}'
                              : 'Chauffeur allocation in progress',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatPaise(assignment.pricePaise),
                        style: AppTypography.titleSmall
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: assignment.status == 'DRIVER_ACCEPTED'
                              ? AppColors.verifiedEmerald
                              : AppColors.softChampagne,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          assignment.status,
                          style: AppTypography.labelSmall.copyWith(
                            color: assignment.status == 'DRIVER_ACCEPTED'
                                ? Colors.white
                                : AppColors.primaryBurgundy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        ShadiCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pricing Summary', style: AppTypography.titleMedium),
              const SizedBox(height: 8),
              _PriceRow(
                  label: 'Estimated total',
                  amount: _formatPaise(group.estimatedTotalPaise)),
              _PriceRow(
                  label: 'Advance token',
                  amount: _formatPaise(group.advanceTokenPaise),
                  emphasized: true),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _InfoCell extends StatelessWidget {
  const _InfoCell({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.warmGold, size: 22),
        const SizedBox(height: 4),
        Text(value, style: AppTypography.titleMedium),
        Text(label,
            style: AppTypography.labelSmall
                .copyWith(color: AppColors.textSecondaryLight)),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.label, required this.amount, this.emphasized});

  final String label;
  final String amount;
  final bool? emphasized;

  @override
  Widget build(BuildContext context) {
    final strong = emphasized ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: strong
                  ? AppTypography.titleSmall
                  : AppTypography.bodyMedium),
          Text(
            amount,
            style: strong
                ? AppTypography.titleSmall
                    .copyWith(fontWeight: FontWeight.w800)
                : AppTypography.bodyMedium,
          ),
        ],
      ),
    );
  }
}
