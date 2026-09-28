import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/route_paths.dart';
import '../../../core/theme/app_typography.dart';
import '../../bookings/presentation/controllers/guest_fleet_selection_controller.dart';
import '../../bookings/presentation/widgets/guest_selection_bar.dart';

/// Customer shell with the bottom navigation. Guest-first: the shell is fully
/// usable signed-out; a non-empty guest selection shows a persistent summary
/// bar ("2 Cars Selected" · `Thar × 2 · Scorpio × 1` → Review Selection) that
/// the composing visitor can always reach, on EVERY tab.
///
/// The bar lives in the Scaffold's `bottomNavigationBar` slot — see
/// [GuestSelectionBar] for why the previous body-`Column` placement made it
/// invisible behind each screen's own footer.
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
          _buildNavigationBar(location, context),
        ],
      ),
    );
  }

  BottomNavigationBar _buildNavigationBar(
    String location,
    BuildContext context,
  ) {
    return BottomNavigationBar(
        currentIndex: _getSelectedIndex(location),
        onTap: (index) => _onItemTapped(index, context),
        selectedLabelStyle: AppTypography.labelSmall.copyWith(
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: AppTypography.labelSmall,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_rounded),
            activeIcon: Icon(Icons.search_rounded),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today_rounded),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            activeIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
    );
  }

  int _getSelectedIndex(String location) {
    if (location.startsWith(RoutePaths.customerSearch)) return 1;
    if (location.startsWith(RoutePaths.customerBookings)) return 2;
    if (location.startsWith(RoutePaths.customerMessages)) return 3;
    if (location.startsWith(RoutePaths.customerProfile) ||
        location.startsWith(RoutePaths.customerAddresses) ||
        location.startsWith(RoutePaths.customerSupportTicket)) {
      return 4;
    }
    return 0; // Default to Home
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(RoutePaths.customerHome);
        break;
      case 1:
        context.go(RoutePaths.customerSearch);
        break;
      case 2:
        context.go(RoutePaths.customerBookings);
        break;
      case 3:
        context.go(RoutePaths.customerMessages);
        break;
      case 4:
        context.go(RoutePaths.customerProfile);
        break;
    }
  }
}
