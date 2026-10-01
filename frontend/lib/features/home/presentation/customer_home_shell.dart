import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_paths.dart';
import '../../bookings/presentation/controllers/guest_fleet_selection_controller.dart';
import '../../bookings/presentation/widgets/guest_selection_bar.dart';

/// Customer shell with the reference bottom navigation (PAGE 02): a 70px
/// ivory translucent bar with a top hairline and four items — Home, Cars,
/// Bookings, Profile — the active item in burgundy with a 2px burgundy
/// indicator on the bar's top edge.
///
/// Guest-first: the shell is fully usable signed-out; a non-empty guest
/// selection shows a persistent summary bar ("2 Cars Selected" ·
/// `Thar × 2 · Scorpio × 1` → Review Selection) that the composing visitor
/// can always reach, on EVERY tab. The bar lives in the Scaffold's
/// `bottomNavigationBar` slot, stacked directly above the nav bar.
class CustomerHomeShell extends ConsumerWidget {
  final Widget child;

  const CustomerHomeShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final selection = ref.watch(guestFleetSelectionProvider);

    // Suppressed while the review screen itself is open: there the selection
    // IS the page, and the bar would only push a copy of it.
    final showSelectionBar = selection.isNotEmpty &&
        !ref.watch(selectionBarSuppressedProvider);

    return Scaffold(
      body: child,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Appears/disappears with a small size transition rather than
          // popping the layout.
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.bottomCenter,
            child: showSelectionBar
                ? GuestSelectionBar(selection: selection)
                : const SizedBox.shrink(),
          ),
          ShadiBottomNav(currentLocation: location),
        ],
      ),
    );
  }
}

/// The reference mobile navigation: Home · Cars · Bookings · Profile.
class ShadiBottomNav extends StatelessWidget {
  final String currentLocation;

  const ShadiBottomNav({super.key, required this.currentLocation});

  static const _items = [
    (icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.directions_car_outlined,
        activeIcon: Icons.directions_car_rounded,
        label: 'Cars'),
    (icon: Icons.calendar_today_outlined,
        activeIcon: Icons.calendar_today_rounded,
        label: 'Bookings'),
    (icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profile'),
  ];

  int get _selectedIndex {
    if (currentLocation.startsWith(RoutePaths.customerSearch)) return 1;
    if (currentLocation.startsWith(RoutePaths.customerBookings)) return 2;
    if (currentLocation.startsWith(RoutePaths.customerProfile) ||
        currentLocation.startsWith(RoutePaths.customerAddresses) ||
        currentLocation.startsWith(RoutePaths.customerSupportTicket)) {
      return 3;
    }
    return 0; // Default to Home
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(RoutePaths.customerHome);
      case 1:
        context.go(RoutePaths.customerSearch);
      case 2:
        context.go(RoutePaths.customerBookings);
      case 3:
        context.go(RoutePaths.customerProfile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedIndex;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF5FDFBF7), // ivory @ .96
        border: Border(top: BorderSide(color: Color(0xFFE7DFD5))),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 70,
              child: Row(
                children: [
                  for (var i = 0; i < _items.length; i++)
                    Expanded(
                      child: _NavItem(
                        data: _items[i],
                        active: i == selected,
                        onTap: () => _onItemTapped(context, i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final ({IconData icon, IconData activeIcon, String label}) data;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.data,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF58111A) : const Color(0xFF918781);
    return Semantics(
      button: true,
      selected: active,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // The reference's active indicator: a 24×2px burgundy bar on the
            // nav bar's top edge (`.mobile-nav button.active:before`).
            if (active)
              Positioned(
                top: 0,
                child: Container(
                  width: 24,
                  height: 2,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  active ? data.activeIcon : data.icon,
                  size: 22,
                  color: color,
                ),
                const SizedBox(height: 4),
                Text(
                  data.label,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: color,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
