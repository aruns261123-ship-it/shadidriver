import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/app/router/app_router.dart';
import 'package:shadidriver/app/router/route_paths.dart';
import 'package:shadidriver/core/config/env_config.dart';
import 'package:shadidriver/core/logging/app_logger.dart';
import 'package:shadidriver/core/network/api_client.dart';
import 'package:shadidriver/core/security/in_memory_secure_storage.dart';
import 'package:shadidriver/features/auth/data/mock_auth_repository.dart';
import 'package:shadidriver/features/auth/domain/entities/user_role.dart';
import 'package:shadidriver/features/auth/presentation/controllers/auth_controller.dart';
import 'package:shadidriver/features/auth/presentation/login_screen.dart';
import 'package:shadidriver/features/bookings/domain/entities/guest_fleet_selection.dart';
import 'package:shadidriver/features/bookings/presentation/controllers/guest_fleet_selection_controller.dart';
import 'package:shadidriver/features/bookings/presentation/group_booking_screen.dart';
import 'package:shadidriver/features/bookings/presentation/widgets/guest_selection_bar.dart';
import 'package:shadidriver/features/home/presentation/customer_home_shell.dart';
import 'package:shadidriver/features/home/presentation/view_models/vehicle_card_view_model.dart';
import 'package:shadidriver/features/vehicles/presentation/widgets/shadi_vehicle_card.dart';

import '../../helpers/mock_env.dart';

/// The selection UX is ONE app-level model (`GuestFleetSelectionController`)
/// that every surface reads and writes. These tests pin the contracts the
/// previous implementation broke:
///
///   * a selected vehicle must be DESELECTABLE from the surface it was added
///     on (the add affordance is a toggle, never a blind increment);
///   * a quantity is a real line quantity, and 0 removes the line;
///   * "Review Selection" must always be reachable once something is selected;
///   * a removal in the review screen must be visible everywhere immediately.
void main() {
  late InMemorySecureStorage secureStorage;
  late MockAuthRepository authRepo;

  setUp(() {
    secureStorage = InMemorySecureStorage();
    authRepo = MockAuthRepository(secureStorage, false);
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        ...mockModeOverrides(),
        authRepositoryProvider.overrideWithValue(authRepo),
        secureStorageProvider.overrideWithValue(secureStorage),
        apiClientProvider.overrideWithValue(_catalogClient()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  GoRouter routerFor(ProviderContainer container, String initialLocation) =>
      createShadiRouter(initialLocation: initialLocation);

  /// Every selection test runs on a real PHONE-sized surface (411x914 dp, the
  /// emulator's Pixel-class viewport), not the 800x600 test default: the whole
  /// point of the selection bar is to be reachable in the space a phone
  /// actually has, under the bottom navigation.
  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1233, 2742);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// Mirrors the real user flow: select a vehicle type, then adjust its
  /// quantity with the stepper. (`setQuantity` alone never invents a line —
  /// it has no metadata to build one from.)
  void seed(
    GuestFleetSelectionController sel, {
    required String id,
    required String displayName,
    required String vehicleClass,
    required int seatingCapacity,
    int quantity = 1,
  }) {
    sel.addType(
      vehicleTypeId: id,
      displayName: displayName,
      vehicleClass: vehicleClass,
      seatingCapacity: seatingCapacity,
    );
    if (quantity != 1) sel.setQuantity(id, quantity);
  }

  Future<void> pumpApp(
    WidgetTester tester,
    ProviderContainer container,
    String initialLocation,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: routerFor(container, initialLocation),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
  }

  // ---------------------------------------------------------------------------
  // Selection model — the single source of truth.
  // ---------------------------------------------------------------------------
  group('guest fleet selection — one source of truth', () {
    test('1. the selection starts empty and requires no account', () {
      final container = makeContainer();
      final selection = container.read(guestFleetSelectionProvider);
      expect(selection.isEmpty, isTrue);
      expect(selection.totalVehicles, 0);
      expect(container.read(activeSessionProvider).isAuthenticated, isFalse);
    });

    test('2. adding a vehicle creates a quantity-1 line', () {
      final container = makeContainer();
      final sel = container.read(guestFleetSelectionProvider.notifier);
      sel.addType(
        vehicleTypeId: 'VT_THAR',
        displayName: 'Mahindra Thar',
        vehicleClass: 'Premium SUV',
        seatingCapacity: 5,
      );

      final state = container.read(guestFleetSelectionProvider);
      expect(state.quantityOf('VT_THAR'), 1);
      expect(state.totalVehicles, 1);
      expect(state.lineForType('VT_THAR')!.displayName, 'Mahindra Thar');
    });

    test('3. selecting the SAME vehicle again increments its quantity', () {
      final container = makeContainer();
      final sel = container.read(guestFleetSelectionProvider.notifier);
      for (var i = 0; i < 2; i++) {
        sel.addType(
          vehicleTypeId: 'VT_THAR',
          displayName: 'Mahindra Thar',
          vehicleClass: 'Premium SUV',
          seatingCapacity: 5,
        );
      }
      final state = container.read(guestFleetSelectionProvider);
      expect(state.lines.length, 1, reason: 'still ONE line, not two');
      expect(state.quantityOf('VT_THAR'), 2);
    });

    test('4. minus decreases the quantity', () {
      final container = makeContainer();
      final sel = container.read(guestFleetSelectionProvider.notifier);
      seed(
        sel,
        id: 'VT_THAR',
        displayName: 'Mahindra Thar',
        vehicleClass: 'Premium SUV',
        seatingCapacity: 5,
        quantity: 4,
      );
      expect(container.read(guestFleetSelectionProvider).quantityOf('VT_THAR'), 4);

      // Each `−` tap lowers the count by one.
      sel.setQuantity('VT_THAR', 3);
      expect(container.read(guestFleetSelectionProvider).quantityOf('VT_THAR'), 3);
    });

    test('5. quantity 0 removes the line entirely (never a 0 line)', () {
      final container = makeContainer();
      final sel = container.read(guestFleetSelectionProvider.notifier);
      seed(
        sel,
        id: 'VT_THAR',
        displayName: 'Mahindra Thar',
        vehicleClass: 'Premium SUV',
        seatingCapacity: 5,
        quantity: 2,
      );
      sel.setQuantity('VT_THAR', 0);

      final state = container.read(guestFleetSelectionProvider);
      expect(state.lines, isEmpty);
      expect(state.containsType('VT_THAR'), isFalse);
      expect(state.totalVehicles, 0);
    });

    test('the quantity can never go negative', () {
      final container = makeContainer();
      final sel = container.read(guestFleetSelectionProvider.notifier);
      seed(
        sel,
        id: 'VT_THAR',
        displayName: 'Mahindra Thar',
        vehicleClass: 'Premium SUV',
        seatingCapacity: 5,
      );
      sel.setQuantity('VT_THAR', -5);
      expect(container.read(guestFleetSelectionProvider).lines, isEmpty);
    });

    test('6. explicit remove takes the line out', () {
      final container = makeContainer();
      final sel = container.read(guestFleetSelectionProvider.notifier);
      seed(
        sel,
        id: 'VT_THAR',
        displayName: 'Mahindra Thar',
        vehicleClass: 'Premium SUV',
        seatingCapacity: 5,
        quantity: 3,
      );
      sel.removeType('VT_THAR');
      expect(container.read(guestFleetSelectionProvider).isEmpty, isTrue);
    });

    test('THE FIX: the add affordance toggles — tapping a selected '
        'vehicle removes it instead of inflating its quantity', () {
      final container = makeContainer();
      final sel = container.read(guestFleetSelectionProvider.notifier);

      final affordance = sel.affordanceFor(
        vehicleTypeId: 'VT_THAR',
        displayName: 'Mahindra Thar',
        vehicleClass: 'Premium SUV',
        seatingCapacity: 5,
      );
      expect(affordance.isSelected, isFalse);
      expect(affordance.quantity, 0);

      // First tap: add.
      affordance.onAdd!();
      final afterAdd = sel.affordanceFor(
        vehicleTypeId: 'VT_THAR',
        displayName: 'Mahindra Thar',
        vehicleClass: 'Premium SUV',
        seatingCapacity: 5,
      );
      expect(afterAdd.isSelected, isTrue);
      expect(afterAdd.quantity, 1);

      // Second tap on the SAME affordance: remove (the old behaviour made
      // this 2, which is why nothing could ever be deselected).
      afterAdd.onAdd!();
      expect(container.read(guestFleetSelectionProvider).isEmpty, isTrue);
      expect(container.read(guestFleetSelectionProvider).totalVehicles, 0);
    });

    test('the stepper removes the line when the last unit is decremented', () {
      final container = makeContainer();
      final sel = container.read(guestFleetSelectionProvider.notifier);
      final affordance = sel.affordanceFor(
        vehicleTypeId: 'VT_THAR',
        displayName: 'Mahindra Thar',
        vehicleClass: 'Premium SUV',
        seatingCapacity: 5,
      );
      affordance.onAdd!();
      affordance.onQuantityChanged!(0);
      expect(container.read(guestFleetSelectionProvider).isEmpty, isTrue);
    });

    test('15. mixed-fleet lines are independent', () {
      final container = makeContainer();
      final sel = container.read(guestFleetSelectionProvider.notifier);
      seed(
        sel,
        id: 'VT_THAR',
        displayName: 'Mahindra Thar',
        vehicleClass: 'Premium SUV',
        seatingCapacity: 5,
        quantity: 2,
      );
      seed(
        sel,
        id: 'VT_SCORPIO',
        displayName: 'Mahindra Scorpio',
        vehicleClass: 'Premium SUV',
        seatingCapacity: 7,
      );
      seed(
        sel,
        id: 'VT_BMW5',
        displayName: 'BMW 5 Series',
        vehicleClass: 'Luxury Sedan',
        seatingCapacity: 4,
      );

      var state = container.read(guestFleetSelectionProvider);
      expect(state.totalVehicles, 4);
      expect(state.lines.length, 3);

      // Removing one type must not touch the others.
      sel.removeType('VT_SCORPIO');
      state = container.read(guestFleetSelectionProvider);
      expect(state.quantityOf('VT_THAR'), 2);
      expect(state.quantityOf('VT_BMW5'), 1);
      expect(state.containsType('VT_SCORPIO'), isFalse);
      expect(state.totalVehicles, 3);
    });

    test('the line summary reads back the composition', () {
      const selection = GuestFleetSelection(
        lines: [
          GuestFleetLine(
            vehicleTypeId: 'VT_THAR',
            displayName: 'Mahindra Thar',
            vehicleClass: 'Premium SUV',
            seatingCapacity: 5,
            quantity: 2,
          ),
          GuestFleetLine(
            vehicleTypeId: 'VT_SCORPIO',
            displayName: 'Mahindra Scorpio',
            vehicleClass: 'Premium SUV',
            seatingCapacity: 7,
            quantity: 1,
          ),
        ],
      );
      expect(selection.totalVehicles, 3);
      expect(selection.totalCapacity, 17);
    });

    test('19. a guest can run the whole add → review → remove → re-add flow '
        'without ever authenticating', () {
      final container = makeContainer();
      final sel = container.read(guestFleetSelectionProvider.notifier);

      sel.addType(
        vehicleTypeId: 'VT_THAR',
        displayName: 'Mahindra Thar',
        vehicleClass: 'Premium SUV',
        seatingCapacity: 5,
      );
      expect(container.read(activeSessionProvider).isAuthenticated, isFalse);

      sel.addType(
        vehicleTypeId: 'VT_SCORPIO',
        displayName: 'Mahindra Scorpio',
        vehicleClass: 'Premium SUV',
        seatingCapacity: 7,
      );
      expect(container.read(guestFleetSelectionProvider).totalVehicles, 2);
      expect(container.read(activeSessionProvider).isAuthenticated, isFalse);

      sel.removeType('VT_SCORPIO');
      expect(container.read(guestFleetSelectionProvider).lines.length, 1);
      expect(container.read(guestFleetSelectionProvider).quantityOf('VT_THAR'), 1);
      expect(container.read(activeSessionProvider).isAuthenticated, isFalse);

      // Re-add after removing — no page reload, no restart.
      sel.addType(
        vehicleTypeId: 'VT_SCORPIO',
        displayName: 'Mahindra Scorpio',
        vehicleClass: 'Premium SUV',
        seatingCapacity: 7,
      );
      expect(container.read(guestFleetSelectionProvider).totalVehicles, 2);
    });

    test('the controller is keep-alive so the selection outlives screens', () {
      final container = makeContainer();
      final notifier = container.read(guestFleetSelectionProvider.notifier);
      notifier.addType(
        vehicleTypeId: 'VT_THAR',
        displayName: 'Mahindra Thar',
        vehicleClass: 'Premium SUV',
        seatingCapacity: 5,
      );
      expect(container.read(guestFleetSelectionProvider.notifier), same(notifier));
      expect(container.read(guestFleetSelectionProvider).totalVehicles, 1);
    });

    test('17. the selection survives the real OTP handoff', () async {
      final container = makeContainer();
      final sel = container.read(guestFleetSelectionProvider.notifier);
      seed(
        sel,
        id: 'VT_THAR',
        displayName: 'Mahindra Thar',
        vehicleClass: 'Premium SUV',
        seatingCapacity: 5,
        quantity: 2,
      );
      seed(
        sel,
        id: 'VT_SCORPIO',
        displayName: 'Mahindra Scorpio',
        vehicleClass: 'Premium SUV',
        seatingCapacity: 7,
      );
      expect(container.read(activeSessionProvider).isAuthenticated, isFalse);

      // The real auth path the app uses at the login detour.
      await authRepo.devSignInAsRole(UserRole.customer);
      await container.read(authControllerProvider.notifier).restoreSession();

      expect(container.read(activeSessionProvider).isAuthenticated, isTrue);
      final afterLogin = container.read(guestFleetSelectionProvider);
      expect(afterLogin.quantityOf('VT_THAR'), 2);
      expect(afterLogin.quantityOf('VT_SCORPIO'), 1);
      expect(afterLogin.totalVehicles, 3);
    });

    test('18. the selection is cleared ONLY by consuming it', () {
      final container = makeContainer();
      final sel = container.read(guestFleetSelectionProvider.notifier);
      seed(
        sel,
        id: 'VT_THAR',
        displayName: 'Mahindra Thar',
        vehicleClass: 'Premium SUV',
        seatingCapacity: 5,
        quantity: 2,
      );
      expect(container.read(guestFleetSelectionProvider).totalVehicles, 2);

      sel.consume();
      expect(container.read(guestFleetSelectionProvider).isEmpty, isTrue);
    });

    test('replaceLines mirrors the composition exactly, deletions included',
        () {
      final container = makeContainer();
      final sel = container.read(guestFleetSelectionProvider.notifier);
      seed(
        sel,
        id: 'VT_THAR',
        displayName: 'Mahindra Thar',
        vehicleClass: 'Premium SUV',
        seatingCapacity: 5,
        quantity: 2,
      );
      seed(
        sel,
        id: 'VT_SCORPIO',
        displayName: 'Mahindra Scorpio',
        vehicleClass: 'Premium SUV',
        seatingCapacity: 7,
      );
      sel.updateTrip(
        const GuestTripDetails(pickupAddress: 'The Oberoi, New Delhi'),
      );

      // The review screen removed Scorpio: the shared selection must follow.
      sel.replaceLines(const [
        GuestFleetLine(
          vehicleTypeId: 'VT_THAR',
          displayName: 'Mahindra Thar',
          vehicleClass: 'Premium SUV',
          seatingCapacity: 5,
          quantity: 2,
        ),
      ]);

      final state = container.read(guestFleetSelectionProvider);
      expect(state.totalVehicles, 2);
      expect(state.containsType('VT_SCORPIO'), isFalse);
      // Trip context is preserved through a composition change.
      expect(state.trip.pickupAddress, 'The Oberoi, New Delhi');
    });
  });

  // ---------------------------------------------------------------------------
  // Surfaces — the UI must derive its state, never remember it.
  // ---------------------------------------------------------------------------
  group('selection surfaces', () {
    testWidgets('7–8. the persistent bar appears with the count, sits ABOVE '
        'the bottom navigation, opens the review screen, and disappears at '
        'zero', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();

      // A minimal shell harness: the bar's job is about the SHELL's layout
      // slot, and this keeps unrelated home-feed widgets out of the frame.
      final router = GoRouter(
        initialLocation: RoutePaths.customerHome,
        routes: [
          ShellRoute(
            builder: (context, state, child) =>
                CustomerHomeShell(child: child),
            routes: [
              GoRoute(
                path: RoutePaths.customerHome,
                builder: (context, state) =>
                    const Scaffold(body: Center(child: Text('Home Content'))),
              ),
              GoRoute(
                path: RoutePaths.customerGroupBooking,
                builder: (context, state) => const GroupBookingScreen(),
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // Nothing selected → no way in, and no stray bar.
      expect(find.byType(GuestSelectionBar), findsNothing);
      expect(find.text('Review Selection'), findsNothing);

      seed(
        container.read(guestFleetSelectionProvider.notifier),
        id: 'VT_BMW5',
        displayName: 'BMW 5 Series',
        vehicleClass: 'Luxury Sedan',
        seatingCapacity: 4,
        quantity: 2,
      );
      await tester.pumpAndSettle();

      expect(find.byType(GuestSelectionBar), findsOneWidget);
      expect(find.text('2 Cars Selected'), findsOneWidget);
      // The bar states the COMPOSITION, not just a number.
      expect(find.text('BMW 5 Series × 2'), findsOneWidget);
      expect(find.text('Review Selection'), findsOneWidget);

      // It is INSIDE the frame, and stacked immediately above the bottom
      // navigation (the bug was a bar that existed but was not reachable).
      final navBar = find.byType(BottomNavigationBar);
      final bar = find.byType(GuestSelectionBar);
      expect(navBar, findsOneWidget);
      expect(
        tester.getBottomLeft(bar).dy,
        lessThanOrEqualTo(914.0),
        reason: 'the bar must be on screen',
      );
      expect(
        tester.getBottomLeft(bar).dy,
        lessThanOrEqualTo(tester.getTopLeft(navBar).dy + 0.5),
        reason: 'the bar must not be buried behind the navigation bar',
      );

      // And it is the way in to the review screen…
      await tester.tap(find.text('Review Selection'));
      await tester.pumpAndSettle();
      expect(find.text('YOUR SELECTION'), findsOneWidget);
      expect(find.text('2 Cars'), findsOneWidget);
      // …where the bar steps aside (it would only stack a second copy).
      expect(find.byType(GuestSelectionBar), findsNothing);

      router.go(RoutePaths.customerHome);
      await tester.pumpAndSettle();
      expect(find.byType(GuestSelectionBar), findsOneWidget);
      container.read(guestFleetSelectionProvider.notifier).removeType(
            'VT_BMW5',
          );
      await tester.pumpAndSettle();
      expect(find.byType(GuestSelectionBar), findsNothing);
      expect(find.text('Review Selection'), findsNothing);
    });

    testWidgets('11–12. search-result cards reflect the shared selection in '
        'both directions', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await pumpApp(tester, container, RoutePaths.customerSearchResults);

      expect(find.text('Add to Selection'), findsWidgets);
      expect(find.text('Selected'), findsNothing);

      // Add from the results list — the real user action.
      final firstAdd = find.text('Add to Selection').first;
      await tester.ensureVisible(firstAdd);
      await tester.tap(firstAdd);
      await tester.pumpAndSettle();

      final selection = container.read(guestFleetSelectionProvider);
      expect(selection.totalVehicles, 1);
      final addedType = selection.lines.single.vehicleTypeId;
      expect(selection.quantityOf(addedType), 1);
      // The card itself now shows the selected state.
      expect(find.text('Selected'), findsWidgets);

      // Removing it (as the review screen would) puts the card back to its
      // unselected state — without any page refresh.
      container
          .read(guestFleetSelectionProvider.notifier)
          .removeType(addedType);
      await tester.pumpAndSettle();
      expect(container.read(guestFleetSelectionProvider).isEmpty, isTrue);
      expect(find.text('Selected'), findsNothing);
      expect(find.text('Add to Selection'), findsWidgets);
    });

    testWidgets('13–14. vehicle details derives its state and can remove',
        (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await pumpApp(
        tester,
        container,
        RoutePaths.customerVehicleDetailsPath('v2'),
      );

      // Not selected: the sticky bar offers the add action.
      expect(find.text('Add to Selection'), findsOneWidget);

      container.read(guestFleetSelectionProvider.notifier).addType(
            vehicleTypeId: 'VT_AUDI_A6',
            displayName: 'Audi A6',
            vehicleClass: 'Premium Sedan',
            seatingCapacity: 4,
          );
      await tester.pumpAndSettle();

      expect(find.text('Add to Selection'), findsNothing);
      expect(find.text('Remove from Selection'), findsOneWidget);

      // Removing from the details page updates the shared selection AND the
      // button, in place.
      await tester.tap(find.text('Remove from Selection'));
      await tester.pumpAndSettle();
      expect(
        container.read(guestFleetSelectionProvider).containsType('VT_AUDI_A6'),
        isFalse,
      );
      expect(find.text('Add to Selection'), findsOneWidget);
    });

    testWidgets('16. the selection survives navigating away and back',
        (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      final router = routerFor(container, RoutePaths.customerSearchResults);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));

      final firstAdd = find.text('Add to Selection').first;
      await tester.ensureVisible(firstAdd);
      await tester.tap(firstAdd);
      await tester.pumpAndSettle();
      final added = container.read(guestFleetSelectionProvider).lines.single;
      expect(added.quantity, 1);

      router.push(RoutePaths.customerVehicleDetailsPath('v2'));
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();

      expect(
        container.read(guestFleetSelectionProvider).quantityOf(added.vehicleTypeId),
        1,
      );
      expect(find.text('Selected'), findsWidgets);
    });

    testWidgets('20. the selection bar does not overflow at a 2x text scale',
        (tester) async {
      usePhoneSurface(tester);
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              bottomNavigationBar: const GuestSelectionBar(
                selection: GuestFleetSelection(
                  lines: [
                    GuestFleetLine(
                      vehicleTypeId: 'VT_THAR',
                      displayName: 'Toyota Innova Crysta Limited Wedding Edition',
                      vehicleClass: 'Executive MPV',
                      seatingCapacity: 6,
                      quantity: 12,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('12 Cars Selected'), findsOneWidget);
      expect(find.text('Review Selection'), findsOneWidget);
    });

    testWidgets('20b. a selected card does not overflow at a 2x text scale',
        (tester) async {
      usePhoneSurface(tester);
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ShadiVehicleCard(
                viewModel: const VehicleCardViewModel(
                  id: 'v1',
                  title: 'Toyota Innova Crysta Limited Wedding Edition',
                  subtitle: '2025 • Executive MPV',
                  ratingText: '4.9',
                  reviewCountText: '(128)',
                  distanceText: '',
                  priceText: '₹25,000',
                  priceUnit: '/ day',
                  hasVerifiedChauffeur: true,
                  isVerifiedVehicle: true,
                  isAvailable: true,
                ),
                onTap: () {},
                onAddToSelection: () {},
                selectedQuantity: 4,
                onQuantityChanged: (_) {},
                onRemoveSelection: () {},
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Selected'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Review Selection screen.
  // ---------------------------------------------------------------------------
  group('review selection screen', () {
    testWidgets('9. shows every selected vehicle line', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      final sel = container.read(guestFleetSelectionProvider.notifier);
      seed(
        sel,
        id: 'VT_INNOVA_CRYSTA',
        displayName: 'Toyota Innova Crysta',
        vehicleClass: 'Executive MPV',
        seatingCapacity: 6,
        quantity: 2,
      );
      seed(
        sel,
        id: 'VT_BMW5',
        displayName: 'BMW 5 Series',
        vehicleClass: 'Luxury Sedan',
        seatingCapacity: 4,
      );

      await pumpApp(tester, container, RoutePaths.customerGroupBooking);

      expect(find.text('YOUR SELECTION'), findsOneWidget);
      expect(find.text('3 Cars Selected'), findsOneWidget);
      // Each type appears in the selection list and in the picker.
      expect(find.textContaining('Innova Crysta'), findsWidgets);
      expect(find.textContaining('BMW 5 Series'), findsWidgets);
      expect(find.text('2 Cars'), findsOneWidget);
      expect(find.text('1 Car'), findsOneWidget);
      expect(find.text('Remove'), findsNWidgets(2));
      expect(find.text('Continue Browsing'), findsOneWidget);
      expect(find.text('Continue to Booking'), findsOneWidget);
      // The bar is suppressed here: this screen IS the selection.
      expect(find.byType(GuestSelectionBar), findsNothing);
    });

    testWidgets('10. removing a line here updates the shared selection and '
        'leaves the other lines alone', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      final sel = container.read(guestFleetSelectionProvider.notifier);
      seed(
        sel,
        id: 'VT_INNOVA_CRYSTA',
        displayName: 'Toyota Innova Crysta',
        vehicleClass: 'Executive MPV',
        seatingCapacity: 6,
        quantity: 2,
      );
      seed(
        sel,
        id: 'VT_BMW5',
        displayName: 'BMW 5 Series',
        vehicleClass: 'Luxury Sedan',
        seatingCapacity: 4,
      );

      await pumpApp(tester, container, RoutePaths.customerGroupBooking);

      // The LAST line is the BMW (insertion order).
      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();

      final state = container.read(guestFleetSelectionProvider);
      expect(state.containsType('VT_BMW5'), isFalse);
      expect(state.quantityOf('VT_INNOVA_CRYSTA'), 2);
      expect(state.totalVehicles, 2);
      expect(find.text('Remove'), findsOneWidget);
      expect(find.text('2 Cars Selected'), findsOneWidget);
    });

    testWidgets('5. removing the FINAL vehicle lands on the empty state',
        (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      seed(
        container.read(guestFleetSelectionProvider.notifier),
        id: 'VT_BMW5',
        displayName: 'BMW 5 Series',
        vehicleClass: 'Luxury Sedan',
        seatingCapacity: 4,
      );

      await pumpApp(tester, container, RoutePaths.customerGroupBooking);
      expect(find.text('1 Car Selected'), findsOneWidget);

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(container.read(guestFleetSelectionProvider).isEmpty, isTrue);
      expect(find.text('No cars selected yet'), findsOneWidget);
      expect(
        find.text('Browse the fleet and add the cars you like.'),
        findsOneWidget,
      );
      expect(find.text('Explore Cars'), findsOneWidget);
      // No orphaned booking action once nothing is selected.
      expect(find.text('Continue to Booking'), findsNothing);
    });

    testWidgets('the quantity stepper on the review screen edits the shared '
        'line', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      seed(
        container.read(guestFleetSelectionProvider.notifier),
        id: 'VT_BMW5',
        displayName: 'BMW 5 Series',
        vehicleClass: 'Luxury Sedan',
        seatingCapacity: 4,
      );

      await pumpApp(tester, container, RoutePaths.customerGroupBooking);

      await tester.tap(find.byTooltip('Increase quantity').first);
      await tester.pumpAndSettle();
      expect(container.read(guestFleetSelectionProvider).quantityOf('VT_BMW5'), 2);
      expect(find.text('2 Cars Selected'), findsOneWidget);

      // Minus at 2 → 1 (still selected)…
      await tester.tap(find.byTooltip('Decrease quantity').first);
      await tester.pumpAndSettle();
      expect(container.read(guestFleetSelectionProvider).quantityOf('VT_BMW5'), 1);
      expect(find.text('1 Car Selected'), findsOneWidget);

      // …and minus at 1 removes the line entirely.
      await tester.tap(find.byTooltip('Remove from selection').first);
      await tester.pumpAndSettle();
      expect(container.read(guestFleetSelectionProvider).isEmpty, isTrue);
      expect(find.text('No cars selected yet'), findsOneWidget);
    });

    testWidgets('12–13. a guest is bounced to authentication (with the '
        'destination preserved) instead of being blocked', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      seed(
        container.read(guestFleetSelectionProvider.notifier),
        id: 'VT_BMW5',
        displayName: 'BMW 5 Series',
        vehicleClass: 'Luxury Sedan',
        seatingCapacity: 4,
      );

      final router = routerFor(container, RoutePaths.customerGroupBooking);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.text('Continue to Booking'));
      await tester.pumpAndSettle();

      // The guest is sent to the REAL login screen (not blocked, not silently
      // dropped), and it carries the way back to this review screen so the
      // post-OTP return lands on the same fleet.
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        tester.widget<LoginScreen>(find.byType(LoginScreen)).redirectTo,
        RoutePaths.customerGroupBooking,
      );
      // The selection is still intact for the post-OTP return.
      expect(container.read(guestFleetSelectionProvider).quantityOf('VT_BMW5'), 1);
    });
  });
}

// -----------------------------------------------------------------------------
// Test support
// -----------------------------------------------------------------------------

/// Answers `GET /v1/vehicles/types` with a small real-shaped catalog.
ApiClient _catalogClient() {
  final adapter = _FakeAdapter((options) {
    if (options.uri.path.endsWith('/vehicles/types')) {
      return jsonEncode({
        'success': true,
        'data': [
          {
            'id': 'VT_INNOVA_CRYSTA',
            'make': 'Toyota',
            'model': 'Innova Crysta',
            'display_name': 'Toyota Innova Crysta',
            'seating_capacity': 6,
            'vehicle_class': 'EXECUTIVE_MPV',
            'image_url': null,
            'amenities': <String>[],
          },
          {
            'id': 'VT_BMW5',
            'make': 'BMW',
            'model': '5 Series',
            'display_name': 'BMW 5 Series',
            'seating_capacity': 4,
            'vehicle_class': 'LUXURY_SEDAN',
            'image_url': null,
            'amenities': <String>[],
          },
        ],
      });
    }
    return jsonEncode({'success': true, 'data': <String, dynamic>{}});
  });

  return ApiClient(
    config: EnvironmentConfig.development(
      apiBaseUrlOverride: 'http://localhost:3000/api',
    ),
    logger: _SilentLogger(),
    secureStorage: InMemorySecureStorage(),
    dio: Dio()..httpClientAdapter = adapter,
  );
}

/// Minimal dio adapter: answers every request from a canned JSON body.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.onRequest);

  final String Function(RequestOptions options) onRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      onRequest(options),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _SilentLogger implements AppLogger {
  @override
  void debug(String message, [Object? error, StackTrace? stackTrace]) {}

  @override
  void info(String message, [Object? error, StackTrace? stackTrace]) {}

  @override
  void warning(String message, [Object? error, StackTrace? stackTrace]) {}

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {}
}
