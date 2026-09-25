import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/home/presentation/view_models/vehicle_card_view_model.dart';
import 'package:shadidriver/features/vehicles/domain/entities/pricing_summary.dart';
import 'package:shadidriver/features/vehicles/domain/entities/vehicle_summary.dart';
import 'package:shadidriver/features/vehicles/presentation/widgets/shadi_vehicle_card.dart';

/// A deliberately hostile view model: the widest plausible strings a real
/// backend row can produce (UUID primary key, long chauffeur-derived copy,
/// un-rounded distances) so the card layout is exercised, not just the happy
/// path with short demo data.
VehicleCardViewModel hostileViewModel() => VehicleCardViewModel(
      id: '661bfb4b-4ac7-44b2-9b8b-76e7a29dd66e',
      title: 'Mercedes-Benz S-Class 580 4MATIC Launch Edition',
      subtitle: '2024 • Ultra Luxury Chauffeur Sedan (Extended Wheelbase)',
      ratingText: '5.0',
      reviewCountText: '(1284)',
      distanceText: '128.5 km away from pickup',
      priceText: '₹1,25,000',
      priceUnit: 'PER CEREMONY DAY (12 HOURS)',
      hasVerifiedChauffeur: true,
      isVerifiedVehicle: true,
      isAvailable: true,
    );

VehicleSummary summaryFor(VehicleCardViewModel vm) => VehicleSummary(
      id: vm.id,
      make: vm.title,
      model: '',
      year: 2024,
      vehicleClass: vm.subtitle,
      registrationNumber: 'FLR-INN-02',
      seatingCapacity: 4,
      verificationStatus: 'VERIFIED',
      rating: 5.0,
      reviewCount: 1284,
      hasVerifiedChauffeur: true,
      pricing: const PricingSummary(basePriceCents: 12500000, billingUnit: 'DAY'),
      distanceKm: 128.5,
      amenities: const ['Dual AC'],
      isAvailableNow: true,
      suitableCeremonies: const ['Baraat'],
    );

/// Pumps the card at an exact width/text scale and returns every layout error
/// Flutter reported while it was laid out and painted, so a failure prints the
/// offending widget instead of just a pixel count.
Future<List<FlutterErrorDetails>> pumpCard(
  WidgetTester tester,
  VehicleCardViewModel viewModel, {
  required double width,
  double textScale = 1.0,
  VoidCallback? onTap,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 900);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });

  final captured = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = captured.add;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ShadiVehicleCard(
              viewModel: viewModel,
              onTap: onTap ?? () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  FlutterError.onError = previous;
  // Drain the binding's capture so it cannot fail the test twice.
  tester.takeException();
  return captured;
}

void expectNoOverflow(List<FlutterErrorDetails> errors, {required double width}) {
  for (final error in errors) {
    debugPrint(error.toString());
  }
  expect(
    errors,
    isEmpty,
    reason: 'The card must lay out without a RenderFlex overflow at '
        '${width}dp (see the diagnostics above for the offending row).',
  );
}

void main() {
  group('ShadiVehicleCard — real backend data renders responsively', () {
    testWidgets('normal vehicle data renders all fields', (tester) async {
      final vm = VehicleCardViewModel.fromEntity(summaryFor(hostileViewModel()));
      final errors = await pumpCard(tester, vm, width: 411);

      expectNoOverflow(errors, width: 411);
      // 12,500,000 paise == ₹1,25,000 rendered through the price formatter.
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('₹1,25,000'),
        ),
        findsOneWidget,
      );
      expect(find.text('View Details'), findsOneWidget);
    });

    testWidgets('no RenderFlex overflow on a small phone (320dp)', (
      tester,
    ) async {
      final errors = await pumpCard(tester, hostileViewModel(), width: 320);

      expectNoOverflow(errors, width: 320);
    });

    testWidgets('no RenderFlex overflow on a normal phone (360dp)', (
      tester,
    ) async {
      final errors = await pumpCard(tester, hostileViewModel(), width: 360);

      expectNoOverflow(errors, width: 360);
    });

    testWidgets('no RenderFlex overflow on a large phone (411dp)', (
      tester,
    ) async {
      final errors = await pumpCard(tester, hostileViewModel(), width: 411);

      expectNoOverflow(errors, width: 411);
    });

    testWidgets('no overflow with a long UUID vehicle id', (tester) async {
      final vm = hostileViewModel();
      expect(vm.id.length, 36);
      final errors = await pumpCard(tester, vm, width: 320);

      expectNoOverflow(errors, width: 320);
    });

    testWidgets('no overflow with long chauffeur / verification copy', (
      tester,
    ) async {
      final errors = await pumpCard(tester, hostileViewModel(), width: 320);

      expectNoOverflow(errors, width: 320);
      expect(find.text('VERIFIED'), findsOneWidget);
    });

    testWidgets('no overflow at increased system text scale', (tester) async {
      final errors = await pumpCard(
        tester,
        hostileViewModel(),
        width: 320,
        textScale: 1.5,
      );

      expectNoOverflow(errors, width: 320);
    });

    testWidgets('action button stays visible and tappable', (tester) async {
      var taps = 0;
      await pumpCard(
        tester,
        hostileViewModel(),
        width: 320,
        onTap: () => taps++,
      );

      final button = find.text('View Details');
      expect(button, findsOneWidget);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(taps, 1);
    });
  });
}
