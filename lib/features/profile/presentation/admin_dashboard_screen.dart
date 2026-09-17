import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/shadi_card.dart';
import '../../../core/widgets/shadi_primary_button.dart';
import '../../../core/widgets/shadi_secondary_button.dart';
import '../../../core/widgets/shadi_status_badge.dart';

/// Chauffeur verification applicant item
class ChauffeurApplicant {
  final String id;
  final String name;
  final String licenseNumber;
  final String vehicleAssigned;
  final String policeClearanceStatus;
  final String attireInspectionStatus;
  String verificationStatus; // 'PENDING', 'APPROVED', 'REJECTED'

  ChauffeurApplicant({
    required this.id,
    required this.name,
    required this.licenseNumber,
    required this.vehicleAssigned,
    required this.policeClearanceStatus,
    required this.attireInspectionStatus,
    this.verificationStatus = 'PENDING',
  });
}

/// Admin Operations Control Center & Chauffeur KYC Hub.
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final List<ChauffeurApplicant> _applicants = [
    ChauffeurApplicant(
      id: 'app_1',
      name: 'Gurpreet Singh',
      licenseNumber: 'DL-04202100892',
      vehicleAssigned: 'Mercedes S-Class (DL-01-AB-1234)',
      policeClearanceStatus: 'Verified (Delhi Police)',
      attireInspectionStatus: 'Passed (Royal Bandhgala & Gold Safa)',
      verificationStatus: 'PENDING',
    ),
    ChauffeurApplicant(
      id: 'app_2',
      name: 'Harish Rawat',
      licenseNumber: 'DL-09201900451',
      vehicleAssigned: 'BMW 5 Series (DL-02-CD-5678)',
      policeClearanceStatus: 'Verified (Gurugram Police)',
      attireInspectionStatus: 'Passed (Ceremonial Safa Inspected)',
      verificationStatus: 'PENDING',
    ),
    ChauffeurApplicant(
      id: 'app_3',
      name: 'Amitav Roy',
      licenseNumber: 'DL-11202200773',
      vehicleAssigned: 'Audi A6 (HR-26-EF-9012)',
      policeClearanceStatus: 'Pending Background Check',
      attireInspectionStatus: 'Inspection Due',
      verificationStatus: 'PENDING',
    ),
  ];

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
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Operations Command Room',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.primaryBurgundy,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Delhi NCR Hub • Live Dispatch & Fleet Operations',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.account_circle_outlined,
              color: AppColors.primaryBurgundy,
            ),
            tooltip: 'Admin Profile & Security',
            onPressed: () => context.push(RoutePaths.adminProfile),
          ),
        ],
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
            Tab(text: 'Live Dispatch'),
            Tab(text: 'Chauffeur KYC'),
            Tab(text: 'Fleet Registry'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLiveDispatchTab(),
          _buildKycQueueTab(),
          _buildFleetRegistryTab(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Live Dispatch Monitor
  // ---------------------------------------------------------------------------
  Widget _buildLiveDispatchTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // KPI Stat Cards
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Live Ceremonies',
                '14',
                Icons.celebration_rounded,
                AppColors.primaryBurgundy,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                'Chauffeurs On-Duty',
                '28',
                Icons.person_pin_rounded,
                AppColors.warmGold,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                'Pending KYC',
                '${_applicants.where((a) => a.verificationStatus == 'PENDING').length}',
                Icons.badge_rounded,
                Colors.orange.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Live Ceremonies List
        Text(
          'Active Ceremonial Dispatch',
          style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),

        _buildDispatchRow(
          bookingRef: 'SD-2026-0100',
          ceremony: 'Baraat Ceremony',
          vehicle: 'BMW 5 Series',
          chauffeur: 'Rajesh Kumar (PB-01)',
          status: 'EN ROUTE',
          statusColor: Colors.blue.shade700,
          route: 'The Oberoi → Grand Imperial Banquets',
        ),
        const SizedBox(height: 10),
        _buildDispatchRow(
          bookingRef: 'SD-2026-0098',
          ceremony: 'Vidai Ceremony',
          vehicle: 'Mercedes S-Class',
          chauffeur: 'Vikram Singh (PB-04)',
          status: 'CEREMONY IN PROGRESS',
          statusColor: AppColors.verifiedEmerald,
          route: 'ITC Maurya → Aerocity Ballroom',
        ),
        const SizedBox(height: 10),
        _buildDispatchRow(
          bookingRef: 'SD-2026-0095',
          ceremony: 'Sangeet Procession',
          vehicle: 'Audi A6',
          chauffeur: 'Manoj Sharma (PB-02)',
          status: 'ARRIVED AT PICKUP',
          statusColor: Colors.purple.shade700,
          route: 'Taj Palace → Chattarpur Farms',
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return ShadiCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.primaryBurgundy,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondaryLight,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDispatchRow({
    required String bookingRef,
    required String ceremony,
    required String vehicle,
    required String chauffeur,
    required String status,
    required Color statusColor,
    required String route,
  }) {
    return ShadiCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                bookingRef,
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBurgundy,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: AppTypography.labelSmall.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$ceremony • $vehicle',
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'Chauffeur: $chauffeur',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.route_rounded,
                size: 14,
                color: AppColors.warmGold,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  route,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Chauffeur KYC & Verification Queue
  // ---------------------------------------------------------------------------
  Widget _buildKycQueueTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _applicants.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final applicant = _applicants[index];
        final isPending = applicant.verificationStatus == 'PENDING';
        final isApproved = applicant.verificationStatus == 'APPROVED';

        return ShadiCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.secondarySurface,
                        child: Text(
                          applicant.name.substring(0, 1),
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.primaryBurgundy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            applicant.name,
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            applicant.licenseNumber,
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ShadiStatusBadge(
                    status: applicant.verificationStatus,
                    color: isApproved
                        ? AppColors.verifiedEmerald
                        : (isPending ? Colors.orange : Colors.red),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.borderLight),
              const SizedBox(height: 10),

              Row(
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    size: 14,
                    color: AppColors.warmGold,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Police Clearance: ${applicant.policeClearanceStatus}',
                    style: AppTypography.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.check_box_outlined,
                    size: 14,
                    color: AppColors.warmGold,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Ceremonial Attire: ${applicant.attireInspectionStatus}',
                    style: AppTypography.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.directions_car_outlined,
                    size: 14,
                    color: AppColors.warmGold,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Vehicle: ${applicant.vehicleAssigned}',
                      style: AppTypography.labelSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Action Buttons
              if (isPending)
                Row(
                  children: [
                    Expanded(
                      child: ShadiPrimaryButton(
                        text: 'Approve KYC',
                        onPressed: () {
                          setState(() {
                            applicant.verificationStatus = 'APPROVED';
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Chauffeur ${applicant.name} approved for ceremonial duty.',
                              ),
                              backgroundColor: AppColors.verifiedEmerald,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ShadiSecondaryButton(
                        text: 'Reject',
                        onPressed: () {
                          setState(() {
                            applicant.verificationStatus = 'REJECTED';
                          });
                        },
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 3: Fleet & Luxury Vehicle Registry
  // ---------------------------------------------------------------------------
  Widget _buildFleetRegistryTab() {
    final fleet = [
      (
        'BMW 5 Series',
        'DL-02-CD-5678',
        'Luxury Sedan',
        'AVAILABLE',
        AppColors.verifiedEmerald,
      ),
      (
        'Mercedes-Benz S-Class',
        'DL-01-AB-1234',
        'Ultra Luxury',
        'ON CEREMONY',
        Colors.blue.shade700,
      ),
      (
        'Audi A6',
        'HR-26-EF-9012',
        'Executive Sedan',
        'AVAILABLE',
        AppColors.verifiedEmerald,
      ),
      (
        'Rolls-Royce Ghost',
        'DL-03-RR-0001',
        'Royal Vintage Class',
        'RESERVED',
        AppColors.primaryBurgundy,
      ),
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: fleet.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final car = fleet[index];
        return ShadiCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.secondarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.directions_car_filled_rounded,
                  color: AppColors.primaryBurgundy,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      car.$1,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${car.$2} • ${car.$3}',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: car.$5.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  car.$4,
                  style: AppTypography.labelSmall.copyWith(
                    color: car.$5,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
