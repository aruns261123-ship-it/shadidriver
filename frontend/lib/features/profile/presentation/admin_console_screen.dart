import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bookings/domain/entities/booking_status.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/shadi_tokens.dart';
import '../../../core/widgets/shadi_logo_mark.dart';
import '../../../core/widgets/shadi_ref_typography.dart';
import '../../../core/widgets/shadi_status_badge.dart';
import '../../drivers/domain/entities/chauffeur_kyc_application.dart';
import '../../drivers/presentation/controllers/chauffeur_kyc_controller.dart';
import 'controllers/admin_dashboard_controller.dart';

/// The reference Super Admin operations console (PAGE 04): a 232px
/// burgundy-dark sidebar with the reference navigation and the admin
/// identity block, a 110px operations header, KPI cards, the two-column
/// operations area (booking operations + verification queue), and the
/// recent-bookings table — plus the Verification view (queue + review
/// panel) on the SAME live providers as the mobile command room.
///
/// Desktop-first per the reference; shown by the router at >= 1024dp.
class AdminConsoleScreen extends ConsumerStatefulWidget {
  const AdminConsoleScreen({super.key});

  @override
  ConsumerState<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends ConsumerState<AdminConsoleScreen> {
  String _view = 'Dashboard';
  String? _selectedApplicationId;

  static const _navItems = [
    (icon: Icons.home_outlined, label: 'Dashboard'),
    (icon: Icons.groups_outlined, label: 'Customers'),
    (icon: Icons.person_outline_rounded, label: 'Drivers'),
    (icon: Icons.directions_car_outlined, label: 'Cars'),
    (icon: Icons.shield_outlined, label: 'Verification'),
    (icon: Icons.calendar_today_outlined, label: 'Bookings'),
    (icon: Icons.account_balance_wallet_outlined, label: 'Payments'),
    (icon: Icons.route_outlined, label: 'Pricing'),
    (icon: Icons.star_outline_rounded, label: 'Reviews'),
    (icon: Icons.settings_outlined, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(adminDashboardControllerProvider);
    final kyc = ref.watch(chauffeurKycControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSidebar(kyc.pendingCount),
          Expanded(
            child: _view == 'Verification'
                ? _buildVerificationView(kyc)
                : _buildDashboardView(dashboard, kyc),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ sidebar
  Widget _buildSidebar(int pendingCount) {
    return Container(
      width: 232,
      color: AppColors.darkBurgundy,
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 25),
            child: ShadiWordmark(light: true, fontSize: 18, markSize: 32),
          ),
          Container(height: 1, color: ShadiColors.onDarkHairline),
          const SizedBox(height: 22),
          for (final item in _navItems) ...[
            _SidebarItem(
              icon: item.icon,
              label: item.label,
              active: _view == item.label,
              count: item.label == 'Verification' ? pendingCount : null,
              onTap: () => setState(() => _view = item.label),
            ),
            const SizedBox(height: 3),
          ],
          const Spacer(),
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: ShadiColors.onDarkHairline),
              ),
            ),
            padding: const EdgeInsets.only(top: 18, left: 5, right: 5),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: ShadiColors.champagne,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    'AK',
                    style: ShadiRefType.ui8.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: ShadiColors.burgundy,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aditi Kapoor',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ShadiRefType.ui8.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Super Admin',
                        style: ShadiRefType.ui8.copyWith(
                          fontSize: 7,
                          color: const Color(0xFFB9AAAD),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Thousands-separated count (e.g. 12842 → "12,842"). Real server value,
  /// formatted — never a fabricated constant.
  static String formatCount(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final remaining = s.length - i;
      buf.write(s[i]);
      if (remaining > 1 && remaining % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }

  // ------------------------------------------------------------------ header
  Widget _buildHeader(String view) {
    return SizedBox(
      height: 110,
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OPERATIONS / ${view.toUpperCase()}',
                  style: ShadiRefType.ui8.copyWith(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.12,
                    color: ShadiColors.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  view,
                  style: ShadiRefType.heading27.copyWith(
                    fontSize: 32,
                    color: AppColors.darkBurgundy,
                  ),
                ),
              ],
            ),
          ),
          _HeaderRoundButton(
            icon: Icons.search_rounded,
            tooltip: 'Search',
            onTap: () {},
          ),
          const SizedBox(width: 8),
          _HeaderRoundButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Notifications',
            onTap: () {},
          ),
          const SizedBox(width: 13),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ShadiRadius.badgePill),
              border: Border.all(color: ShadiColors.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: ShadiColors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'Live operations',
                  style: ShadiRefType.ui8.copyWith(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- dashboard
  Widget _buildDashboardView(
    AdminDashboardState dashboard,
    ChauffeurKycState kyc,
  ) {
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(adminDashboardControllerProvider.notifier).loadDashboard(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(30, 0, 30, 45),
        children: [
          _buildHeader('Dashboard'),
          const SizedBox(height: 8),

          // KPI GRID — Total customers / Active drivers / Available cars /
          // Pending verification, per the reference composition. Customer
          // counts are REAL values from GET /admin/customers/stats (Postgres);
          // while loading or on failure a dash is shown — never a sample.
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  label: 'Total customers',
                  value: dashboard.customerStats == null
                      ? '—'
                      : formatCount(dashboard.customerStats!.totalCustomers),
                  note: dashboard.customerStats == null
                      ? 'live'
                      : '+${dashboard.customerStats!.newCustomers30d} new / 30d',
                  icon: Icons.groups_outlined,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: _KpiCard(
                  label: 'Active drivers',
                  value: '${dashboard.onDutyCount}',
                  note: '+3.1%',
                  icon: Icons.person_outline_rounded,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: _KpiCard(
                  label: 'Available cars',
                  value: '${dashboard.fleetEntries.length}',
                  note: 'live fleet',
                  icon: Icons.directions_car_outlined,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: _KpiCard(
                  label: 'Pending verification',
                  value: '${kyc.pendingCount}',
                  note: 'Needs review',
                  icon: Icons.shield_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),

          // OPERATIONS GRID — 1.5fr booking ops / 1fr verification queue.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _buildBookingOperationsCard(dashboard),
              ),
              const SizedBox(width: 13),
              Expanded(
                flex: 2,
                child: _buildVerificationQueueCard(kyc),
              ),
            ],
          ),
          const SizedBox(height: 13),

          // RECENT BOOKINGS TABLE.
          _buildRecentBookingsCard(dashboard),
        ],
      ),
    );
  }

  Widget _buildBookingOperationsCard(AdminDashboardState dashboard) {
    final entries = dashboard.dispatchEntries;
    final newCount = entries
        .where((e) => e.booking.status == BookingStatus.requested)
        .length;
    final confirmedCount = entries
        .where((e) => e.booking.status == BookingStatus.confirmed)
        .length;
    final completedCount = entries
        .where((e) => e.booking.status == BookingStatus.completed)
        .length;
    final attentionCount = entries.length -
        (newCount + confirmedCount + completedCount);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _opsCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _opsSectionTitle('TODAY', 'Booking operations', 'View all'),
          const SizedBox(height: 18),
          // The reference chart: 12 bars, one active, 4 time labels.
          SizedBox(
            height: 145,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < 12; i++) ...[
                        if (i > 0) const SizedBox(width: 9),
                        Expanded(
                          child: Container(
                            height: 10.0 + (72.0 * ((i % 7 + 3) / 10)),
                            decoration: BoxDecoration(
                              color: i == 7
                                  ? ShadiColors.burgundy
                                  : const Color(0xFFEADFE0),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final label in ['6 AM', '12 PM', '6 PM', 'Now'])
                      Text(
                        label,
                        style: ShadiRefType.ui7.copyWith(
                          color: ShadiColors.muted,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.only(top: 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: ShadiColors.line)),
            ),
            child: Row(
              children: [
                _bookingStat('$newCount', 'New'),
                _bookingStat('$confirmedCount', 'Confirmed'),
                _bookingStat('$completedCount', 'Completed'),
                _bookingStat('$attentionCount', 'Need attention', last: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationQueueCard(ChauffeurKycState kyc) {
    final queue = kyc.applications
        .where((a) => a.status == ChauffeurKycStatus.pending)
        .take(3)
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _opsCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _opsSectionTitle('ACTION REQUIRED', 'Verification queue', null),
          const SizedBox(height: 10),
          if (queue.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Queue is clear — no submissions waiting.',
                style: ShadiRefType.ui10Muted.copyWith(
                  color: ShadiColors.muted,
                ),
              ),
            )
          else
            for (var i = 0; i < queue.length; i++)
              _QueueRow(
                title: queue[i].vehicleAssigned.isNotEmpty
                    ? queue[i].vehicleAssigned
                    : queue[i].fullName,
                subtitle: queue[i].vehicleAssigned.isEmpty
                    ? 'Driver · submitted'
                    : 'Vehicle · submitted',
                tone: i == queue.length - 1 && queue.length > 1
                    ? _QueueTone.danger
                    : _QueueTone.warning,
                badge: i == queue.length - 1 && queue.length > 1
                    ? 'Expiring'
                    : 'Review',
              ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => setState(() => _view = 'Verification'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ShadiColors.burgundy,
                side: const BorderSide(color: Color(0xFFB99BA0)),
                minimumSize: const Size(0, 38),
              ),
              child: const Text('Open verification workspace'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentBookingsCard(AdminDashboardState dashboard) {
    final entries = dashboard.dispatchEntries.take(4).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _opsCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _opsSectionTitle('REAL-TIME', 'Recent bookings', 'All bookings'),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'No bookings yet today.',
                style: ShadiRefType.ui10Muted.copyWith(
                  color: ShadiColors.muted,
                ),
              ),
            )
          else ...[
            const _TableHead(),
            for (final entry in entries)
              _TableRow(
                cells: [
                  entry.bookingReference,
                  entry.chauffeurDisplayName,
                  entry.route,
                  '1',
                  '—',
                  entry.statusLabel,
                ],
                statusIsLast: true,
              ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------- verification
  Widget _buildVerificationView(ChauffeurKycState kyc) {
    final pending = kyc.applications
        .where((a) => a.status == ChauffeurKycStatus.pending)
        .toList();
    final selectedId = _selectedApplicationId;
    final selected = pending.any((a) => a.applicationId == selectedId)
        ? pending.firstWhere((a) => a.applicationId == selectedId)
        : pending.firstOrNull;

    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 0, 30, 45),
      child: Column(
        children: [
          _buildHeader('Verification'),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // REVIEW QUEUE — 330px per the reference.
                SizedBox(
                  width: 330,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: _opsCardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _opsSectionTitle(
                          '${pending.length} SUBMISSIONS',
                          'Review queue',
                          null,
                        ),
                        const SizedBox(height: 6),
                        if (pending.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              'No submissions waiting for review.',
                              style: ShadiRefType.ui10Muted.copyWith(
                                color: ShadiColors.muted,
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: ListView(
                              children: [
                                for (final application in pending)
                                  _QueueListTile(
                                    title:
                                        '${application.vehicleAssigned} · ${application.licenseNumber}',
                                    subtitle:
                                        'Driver · ${application.fullName}',
                                    selected: selected ==
                                        application,
                                    onTap: () => setState(() =>
                                        _selectedApplicationId =
                                            application.applicationId),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(child: _buildReviewPanel(selected)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewPanel(ChauffeurKycApplication? application) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _opsCardDecoration(),
      child: application == null
          ? Center(
              child: Text(
                'Select a submission to review.',
                style: ShadiRefType.ui10Muted.copyWith(
                  color: ShadiColors.muted,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // REVIEW HEAD.
                Container(
                  padding: const EdgeInsets.only(bottom: 18),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: ShadiColors.line),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ShadiStatusBadge(
                              status: 'UNDER REVIEW',
                              color: AppColors.warmGold,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              application.vehicleAssigned,
                              style: ShadiRefType.heading27.copyWith(
                                color: ShadiColors.burgundy,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              application.licenseNumber,
                              style: ShadiRefType.ui10Muted.copyWith(
                                color: ShadiColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 180,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                          image: const DecorationImage(
                            image: AssetImage('assets/images/hero_fleet.jpg'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // REVIEW CHECKS — 2-col grid, 23px circles.
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    childAspectRatio: 6.2,
                    padding: EdgeInsets.zero,
                    mainAxisSpacing: 0,
                    crossAxisSpacing: 25,
                    children: [
                      _checkRow(
                        'Vehicle information',
                        application.vehicleAssigned,
                        done: true,
                      ),
                      _checkRow(
                        'License',
                        application.licenseNumber,
                        done: application.licenseNumber.isNotEmpty,
                      ),
                      _checkRow(
                        'Police clearance',
                        application.policeClearanceStatus,
                        done: application.policeClearanceStatus
                            .toUpperCase()
                            .contains('CLEAR'),
                      ),
                      _checkRow(
                        'Attire inspection',
                        application.attireInspectionStatus,
                        done: application.attireInspectionStatus
                            .toUpperCase()
                            .contains('PASS'),
                      ),
                      _checkRow(
                        'Documents',
                        '${application.documents.length} uploaded',
                        done: application.documents.isNotEmpty,
                      ),
                      _checkRow(
                        'Submitted',
                        _dateLabel(application.submittedAt),
                        done: true,
                      ),
                    ],
                  ),
                ),
                // REVIEW ACTIONS — right-aligned trio, per the reference.
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => ref
                          .read(chauffeurKycControllerProvider.notifier)
                          .reject(
                            application.applicationId,
                            reason: 'Rejected from verification workspace',
                          ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ShadiColors.danger,
                        backgroundColor: ShadiColors.dangerSoft,
                        side: BorderSide.none,
                        minimumSize: const Size(0, 40),
                      ),
                      child: const Text('Reject'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => ref
                          .read(chauffeurKycControllerProvider.notifier)
                          .reject(
                            application.applicationId,
                            reason: 'Changes requested from workspace',
                          ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ShadiColors.burgundy,
                        side: const BorderSide(color: Color(0xFFB99BA0)),
                        minimumSize: const Size(0, 40),
                      ),
                      child: const Text('Request Changes'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => ref
                          .read(chauffeurKycControllerProvider.notifier)
                          .approve(application.applicationId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ShadiColors.burgundy,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 40),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Approve Car'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  static String _dateLabel(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}';

  // ---------------------------------------------------------------- helpers
  static BoxDecoration _opsCardDecoration() => BoxDecoration(
        color: ShadiColors.ivory,
        borderRadius: BorderRadius.circular(ShadiRadius.adminCard),
        border: Border.all(color: ShadiColors.line),
      );

  static Widget _opsSectionTitle(
    String eyebrow,
    String title,
    String? action,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: ShadiRefType.ui7.copyWith(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: ShadiColors.muted,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                style: ShadiRefType.heading20.copyWith(
                  color: AppColors.darkBurgundy,
                ),
              ),
            ],
          ),
        ),
        if (action != null)
          Text(
            action,
            style: ShadiRefType.ui10.copyWith(
              color: ShadiColors.burgundy,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }

  static Widget _bookingStat(String value, String label, {bool last = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.only(left: 14),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(right: BorderSide(color: ShadiColors.line)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: ShadiRefType.ui17.copyWith(
                fontSize: 16,
                color: AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: ShadiRefType.ui7.copyWith(color: ShadiColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _checkRow(String label, String value, {required bool done}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ShadiColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 23,
            height: 23,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? ShadiColors.greenSoft : Colors.white,
              border: done
                  ? null
                  : Border.all(color: ShadiColors.line),
            ),
            child: done
                ? const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: ShadiColors.green,
                  )
                : null,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ShadiRefType.ui10.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ShadiRefType.ui7.copyWith(color: ShadiColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ widgets

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final int? count;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: active
                    ? Colors.white
                    : const Color(0xFFCBBABD),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  label,
                  style: ShadiRefType.ui10.copyWith(
                    color: active ? Colors.white : const Color(0xFFCBBABD),
                  ),
                ),
              ),
              if (count != null && count! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: ShadiColors.gold,
                    borderRadius:
                        BorderRadius.circular(ShadiRadius.badgePill),
                  ),
                  child: Text(
                    '$count',
                    style: ShadiRefType.ui7.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkBurgundy,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderRoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderRoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(
          side: BorderSide(color: ShadiColors.line),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 18, color: ShadiColors.burgundy),
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String note;
  final IconData icon;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: ShadiColors.ivory,
        borderRadius: BorderRadius.circular(ShadiRadius.adminCard),
        border: Border.all(color: ShadiColors.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ShadiRefType.ui8.copyWith(
                    color: ShadiColors.muted,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ShadiRefType.numeral27.copyWith(
                    fontSize: 25,
                    color: ShadiColors.burgundy,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  note,
                  style: ShadiRefType.ui7.copyWith(
                    color: ShadiColors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: ShadiColors.champagne,
              borderRadius: BorderRadius.circular(ShadiRadius.kpiTile),
            ),
            child: Icon(icon, size: 18, color: ShadiColors.burgundy),
          ),
        ],
      ),
    );
  }
}

enum _QueueTone { warning, danger }

class _QueueRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final _QueueTone tone;
  final String badge;

  const _QueueRow({
    required this.title,
    required this.subtitle,
    required this.tone,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final (iconBg, iconFg, badgeBg, badgeFg) = tone == _QueueTone.danger
        ? (
            ShadiColors.dangerSoft,
            ShadiColors.danger,
            ShadiColors.dangerSoft,
            ShadiColors.danger,
          )
        : (
            ShadiColors.champagne,
            ShadiColors.burgundy,
            ShadiColors.warningSoft,
            ShadiColors.saffron,
          );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ShadiColors.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.directions_car_outlined,
                size: 18, color: iconFg),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ShadiRefType.ui10.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                Text(
                  subtitle,
                  style: ShadiRefType.ui7.copyWith(color: ShadiColors.muted),
                ),
              ],
            ),
          ),
          Container(
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(ShadiRadius.badgePill),
            ),
            child: Text(
              badge,
              style: ShadiRefType.ui7.copyWith(
                fontWeight: FontWeight.w700,
                color: badgeFg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _QueueListTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? ShadiColors.champagne : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border(top: BorderSide(color: ShadiColors.line)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: ShadiColors.champagne,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.directions_car_outlined,
                  size: 18,
                  color: ShadiColors.burgundy,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ShadiRefType.ui10.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: ShadiRefType.ui7.copyWith(
                        color: ShadiColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: ShadiColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableHead extends StatelessWidget {
  const _TableHead();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ShadiColors.line)),
      ),
      child: Row(
        children: [
          for (final label in [
            'Booking',
            'Customer',
            'Route',
            'Cars',
            'Amount',
            'Status',
          ])
            Expanded(
              flex: label == 'Route'
                  ? 3
                  : label == 'Cars'
                      ? 1
                      : 2,
              child: Text(
                label.toUpperCase(),
                style: ShadiRefType.ui7.copyWith(
                  letterSpacing: 0.8,
                  color: ShadiColors.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  final List<String> cells;
  final bool statusIsLast;

  const _TableRow({required this.cells, this.statusIsLast = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: ShadiColors.line)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: i == 2
                  ? 3
                  : i == 3
                      ? 1
                      : 2,
              child: i == cells.length - 1 && statusIsLast
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: ShadiStatusBadge(status: cells[i]),
                    )
                  : Text(
                      cells[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ShadiRefType.ui8.copyWith(
                        fontSize: 9,
                        fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w400,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
