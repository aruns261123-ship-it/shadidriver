import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';import 'package:shadidriver/app/providers/partner_providers.dart';
import 'package:shadidriver/core/network/api_response.dart';
import 'package:shadidriver/core/result/result.dart';
import 'package:shadidriver/features/partner/domain/entities/partner_enums.dart';
import 'package:shadidriver/features/partner/domain/entities/partner_profile.dart';
import 'package:shadidriver/features/partner/domain/entities/partner_vehicle.dart';
import 'package:shadidriver/features/partner/domain/repositories/partner_repository.dart';
import 'package:shadidriver/features/partner/presentation/controllers/partner_onboarding_controller.dart';
import 'package:shadidriver/features/partner/presentation/partner_onboarding_screen.dart';
import 'package:shadidriver/features/partner/presentation/partner_vehicle_pricing_screen.dart';
import 'package:shadidriver/features/partner/presentation/widgets/partner_fleet_list.dart';
import 'package:shadidriver/features/partner/presentation/widgets/partner_review_screen.dart';

/// Deterministic fake — records calls and converts injected transport errors
/// into Result.failure exactly like the real repository does via mapDioError.
class _FakePartnerRepository implements PartnerRepository {
  PartnerProfile? profile;
  List<PartnerVehicle> fleet = const [];
  List<VehicleTariff> tariffs = const [];
  final List<String> calls = [];
  Object? throwOnNext;

  /// A real fleet fetch spans several frames. Injecting the same delay is what
  /// makes "is this stage reloading itself forever?" observable in a test —
  /// with an instant future every state change lands inside one frame.
  Duration listFleetDelay = Duration.zero;

  _FakePartnerRepository({this.profile});

  Future<Result<T>> _guard<T>(String op, Result<T> Function() body) async {
    calls.add(op);
    final error = throwOnNext;
    if (error != null) {
      throwOnNext = null;
      // Mirror the real repository: failures become typed Results.
      return Result.failure(mapDioError(error));
    }
    return body();
  }

  @override
  Future<Result<PartnerProfile>> register(PartnerRegistrationDraft draft) async {
    return _guard('register', () {
      profile = _copyWithStatus(
          profile ?? defaultProfile, PartnerVerificationStatus.pendingSubmission);
      return Result.success(profile!);
    });
  }

  @override
  Future<Result<PartnerProfile>> getProfile() async =>
      _guard('getProfile', () => Result.success(profile!));

  @override
  Future<Result<PartnerProfile>> updateProfile(
    PartnerRegistrationDraft draft,
  ) async =>
      _guard('updateProfile', () => Result.success(profile!));

  @override
  Future<Result<PartnerFleet>> listFleet() async {
    calls.add('listFleet');
    if (listFleetDelay > Duration.zero) {
      await Future<void>.delayed(listFleetDelay);
    }
    final error = throwOnNext;
    if (error != null) {
      throwOnNext = null;
      return Result.failure(mapDioError(error));
    }
    return Result.success(PartnerFleet(items: fleet, total: fleet.length));
  }

  @override
  Future<Result<PartnerVehicle>> addVehicle(PartnerVehicleDraft draft) async =>
      _guard('addVehicle', () => Result.success(fleet.first));

  @override
  Future<Result<PartnerVehicle>> updateVehicle(
    String vehicleId,
    PartnerVehicleEditDraft draft,
  ) async =>
      _guard('updateVehicle', () => Result.success(fleet.first));

  @override
  Future<Result<void>> removeVehicle(String vehicleId) async =>
      _guard('removeVehicle', () => const Result.success(null));

  @override
  Future<Result<void>> addVehicleDocument(
    String vehicleId,
    VehicleDocumentDraft draft,
  ) async =>
      _guard('addVehicleDocument', () => const Result.success(null));

  @override
  Future<Result<List<VehicleTariff>>> listTariffs(String vehicleId) async =>
      _guard('listTariffs', () => Result.success(tariffs));

  @override
  Future<Result<VehicleTariff>> submitTariff(
    String vehicleId,
    VehicleTariffDraft draft,
  ) async =>
      _guard('submitTariff', () => Result.success(tariffs.first));

  @override
  Future<Result<PartnerProfile>> submitForVerification() async =>
      _guard('submitForVerification', () {
        profile = _copyWithStatus(profile!, PartnerVerificationStatus.submitted);
        return Result.success(profile!);
      });

  static PartnerProfile get defaultProfile => PartnerProfile(
        id: 'partner-1',
        companyName: 'Sharma Wedding Fleets',
        contactName: 'Rakesh Sharma',
        baseCity: 'Delhi NCR',
        serviceCities: const ['Delhi NCR'],
        languagesSpoken: const ['Hindi'],
        experienceYears: 7,
        verificationStatus: PartnerVerificationStatus.pendingSubmission,
        submittedAt: null,
        reviewedAt: null,
        decisionReason: null,
      );

  static PartnerProfile _copyWithStatus(
      PartnerProfile p, PartnerVerificationStatus status) {
    return PartnerProfile(
      id: p.id,
      companyName: p.companyName,
      contactName: p.contactName,
      baseCity: p.baseCity,
      serviceCities: p.serviceCities,
      languagesSpoken: p.languagesSpoken,
      experienceYears: p.experienceYears,
      verificationStatus: status,
      submittedAt: status == PartnerVerificationStatus.submitted
          ? DateTime(2026, 9, 27)
          : null,
      reviewedAt: null,
      decisionReason: null,
      vehicleCount: p.vehicleCount,
      documentCount: p.documentCount,
    );
  }
}

PartnerVehicle _vehicle({
  String id = 'vh-1',
  String? displayName,
  String plate = 'DL01AB1234',
  PartnerVerificationStatus status = PartnerVerificationStatus.pendingSubmission,
  List<PartnerVehicleDocument> documents = const [],
}) {
  return PartnerVehicle(
    id: id,
    fleetCode: 'SD-VH-$id',
    vehicleTypeId: 'VT_THAR',
    displayName: displayName,
    seatingCapacity: 5,
    vehicleClass: 'LUXURY_SUV',
    year: 2024,
    registrationNumber: plate,
    color: 'Everest White',
    fuelType: 'DIESEL',
    transmission: 'MANUAL',
    city: 'Delhi NCR',
    serviceAreas: const [],
    amenities: const [],
    photoUrls: const [],
    verificationStatus: status,
    isActive: true,
    isAvailable: true,
    isBookable: status == PartnerVerificationStatus.approved,
    documents: documents,
  );
}

Widget _host(List<Override> overrides, Widget child) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: child),
  );
}

void main() {
  late _FakePartnerRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = _FakePartnerRepository(profile: _FakePartnerRepository.defaultProfile);
    container = ProviderContainer(overrides: [
      partnerRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
  });

  group('PartnerFleetList (MY FLEET)', () {
    testWidgets('renders the tally line, masked plates and per-vehicle status',
        (tester) async {
      final fleet = PartnerFleet(
        items: [
          _vehicle(
              id: 'vh-1',
              displayName: 'Toyota Thar',
              status: PartnerVerificationStatus.approved),
          _vehicle(
              id: 'vh-2',
              displayName: 'Toyota Thar',
              plate: 'DL02XY9090',
              status: PartnerVerificationStatus.submitted),
          _vehicle(
              id: 'vh-3',
              displayName: 'Mahindra Scorpio',
              plate: 'DL03LM5678',
              status: PartnerVerificationStatus.actionRequired,
              documents: const [
                PartnerVehicleDocument(
                  type: 'COMMERCIAL_INSURANCE',
                  status: PartnerVerificationStatus.actionRequired,
                  expiresAt: null,
                ),
              ]),
        ],
        total: 3,
      );

      await tester.pumpWidget(
        _host([partnerRepositoryProvider.overrideWithValue(repo)],
            PartnerFleetList(fleet: fleet)),
      );
      await tester.pump();

      expect(find.text('MY FLEET'), findsOneWidget);
      expect(find.text('3 Vehicles'), findsOneWidget);
      expect(find.textContaining('Verified'), findsWidgets);
      expect(find.textContaining('Changes Required'), findsWidgets);

      expect(find.text('Toyota Thar'), findsNWidgets(2));
      expect(find.text('Mahindra Scorpio'), findsOneWidget);
      expect(find.textContaining('•••• 1234'), findsOneWidget);
      expect(find.textContaining('•••• 9090'), findsOneWidget);
      expect(find.textContaining('•••• 5678'), findsOneWidget);
      expect(find.textContaining('DL01AB1234'), findsNothing);

      expect(find.text('APPROVED'), findsOneWidget);
      expect(find.text('SUBMITTED'), findsOneWidget);
      expect(find.text('ACTION REQUIRED'), findsOneWidget);
    });

    // A partner's first vehicle is PENDING_SUBMISSION until they press submit.
    // The tally has to count it, and "1 Vehicles" is not English.
    testWidgets('a single not-yet-submitted vehicle still counts in the tally',
        (tester) async {
      final fleet = PartnerFleet(
        items: [_vehicle(id: 'vh-1', displayName: 'Toyota Innova Crysta')],
        total: 1,
      );

      await tester.pumpWidget(
        _host([partnerRepositoryProvider.overrideWithValue(repo)],
            PartnerFleetList(fleet: fleet)),
      );
      await tester.pump();

      expect(find.text('1 Vehicle'), findsOneWidget);
      expect(find.text('1 Vehicles'), findsNothing);
      expect(find.textContaining('Awaiting Submission'), findsOneWidget);
      // The fleet is not empty just because nothing has been verified yet.
      expect(find.text('No vehicles yet'), findsNothing);
    });

    testWidgets('an empty fleet is the only case that reads "No vehicles yet"',
        (tester) async {
      await tester.pumpWidget(
        _host([partnerRepositoryProvider.overrideWithValue(repo)],
            const PartnerFleetList(fleet: PartnerFleet(items: [], total: 0))),
      );
      await tester.pump();

      expect(find.text('0 Vehicles'), findsOneWidget);
      expect(find.text('No vehicles yet'), findsOneWidget);
    });

    testWidgets('tapping a vehicle card starts the edit flow', (tester) async {
      final fleet = PartnerFleet(
        items: [_vehicle(id: 'vh-9', displayName: 'Toyota Thar')],
        total: 1,
      );
      await tester.pumpWidget(
        _host([partnerRepositoryProvider.overrideWithValue(repo)],
            PartnerFleetList(fleet: fleet)),
      );
      await tester.pump();

      final listContext = tester.element(find.byType(PartnerFleetList));
      await tester.tap(find.text('Toyota Thar'));
      await tester.pump();

      // The widget tree owns the scoped container — read state through it.
      final state = ProviderScope.containerOf(listContext)
          .read(partnerOnboardingProvider);
      expect(state.stage, OnboardingStage.vehicleForm);
      expect(state.editingVehicle!.id, 'vh-9');
    });
  });

  group('PartnerReviewScreen', () {
    testWidgets('shows partner summary, fleet and the submit button',
        (tester) async {
      final profile = _FakePartnerRepository.defaultProfile;
      repo.fleet = [
        _vehicle(id: 'vh-1', displayName: 'Toyota Thar'),
        _vehicle(
            id: 'vh-2',
            displayName: 'Mahindra Scorpio',
            plate: 'DL02CD5678'),
      ];
      container.read(partnerOnboardingProvider.notifier);

      await tester.pumpWidget(
        _host([partnerRepositoryProvider.overrideWithValue(repo)],
            PartnerReviewScreen(profile: profile, vehicle: null)),
      );
      await tester.pump();

      expect(find.text('Review & Submit'), findsOneWidget);
      expect(find.text('Partner Details'), findsOneWidget);
      expect(find.text('Sharma Wedding Fleets'), findsOneWidget);
      expect(find.text('Fleet'), findsOneWidget);
      expect(find.textContaining('Toyota Thar'), findsOneWidget);
      expect(find.textContaining('Mahindra Scorpio'), findsOneWidget);
      expect(find.text('Submit for Verification'), findsOneWidget);
    });

    testWidgets(
        'submitting advances the partner to SUBMITTED (never a fake verified)',
        (tester) async {
      final profile = _FakePartnerRepository.defaultProfile;
      repo.fleet = [_vehicle(id: 'vh-1', displayName: 'Toyota Thar')];
      container.read(partnerOnboardingProvider.notifier);

      await tester.pumpWidget(
        _host([partnerRepositoryProvider.overrideWithValue(repo)],
            PartnerReviewScreen(profile: profile, vehicle: null)),
      );
      await tester.pump();

      final screenContext = tester.element(find.byType(PartnerReviewScreen));
      await tester.tap(find.text('Submit for Verification'));
      await tester.pumpAndSettle();

      final state = ProviderScope.containerOf(screenContext)
          .read(partnerOnboardingProvider);
      expect(state.submittedForReview, isTrue);
      expect(
          state.profile!.verificationStatus, PartnerVerificationStatus.submitted);
      expect(repo.calls, contains('submitForVerification'));
    });

    testWidgets('a backend refusal (no vehicles) surfaces on the review screen',
        (tester) async {
      final profile = _FakePartnerRepository.defaultProfile;
      repo.fleet = const []; // backend refuses submission with no fleet
      container.read(partnerOnboardingProvider.notifier);

      await tester.pumpWidget(
        _host([partnerRepositoryProvider.overrideWithValue(repo)],
            PartnerReviewScreen(profile: profile, vehicle: null)),
      );
      await tester.pump();

      // Inject the backend refusal the real service returns for an empty fleet.
      repo.throwOnNext = DioException(
        requestOptions: RequestOptions(path: '/api/v1/partner/submit'),
        type: DioExceptionType.badResponse,
        response: Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/api/v1/partner/submit'),
          statusCode: 400,
          data: {
            'success': false,
            'error': {
              'code': 'VALIDATION_FAILED',
              'message':
                  'Add at least one vehicle before submitting for verification.',
            },
          },
        ),
      );

      final screenContext = tester.element(find.byType(PartnerReviewScreen));
      await tester.tap(find.text('Submit for Verification'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Add at least one vehicle before submitting'),
        findsOneWidget,
      );
      // Partner remains pending — never pretend verification is done.
      final state = ProviderScope.containerOf(screenContext)
          .read(partnerOnboardingProvider);
      expect(state.submittedForReview, isFalse);
      expect(
        state.profile!.verificationStatus,
        PartnerVerificationStatus.pendingSubmission,
      );
    });
  });

  // A customer-role session is refused by every partner endpoint with
  // 403 ROLE_FORBIDDEN. The portal must say so in plain language instead of
  // rendering the details form and failing on submit.
  group('PartnerOnboardingScreen role gate', () {
    DioException forbidden() => DioException(
          requestOptions: RequestOptions(path: '/api/v1/partner/profile'),
          type: DioExceptionType.badResponse,
          response: Response<Map<String, dynamic>>(
            requestOptions: RequestOptions(path: '/api/v1/partner/profile'),
            statusCode: 403,
            data: {
              'success': false,
              'error': {
                'code': 'ROLE_FORBIDDEN',
                'message':
                    'Your role does not have permission to perform this action.',
              },
            },
          ),
        );

    testWidgets('customer session is told a partner account is needed',
        (tester) async {
      repo.throwOnNext = forbidden();

      await tester.pumpWidget(
        _host(
          [partnerRepositoryProvider.overrideWithValue(repo)],
          const PartnerOnboardingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('A partner account is needed'), findsOneWidget);
      expect(find.textContaining('reserved for chauffeur'), findsOneWidget);
      expect(find.text('Back to My Account'), findsOneWidget);
      // Not the fleet-building surface, and not a raw backend error string.
      expect(find.text('+ Add Vehicle'), findsNothing);
      expect(
        find.textContaining('Your role does not have permission'),
        findsNothing,
      );
    });
  });

  // Regression: the review stage reloads the fleet on entry. If that reload
  // also drove the shell's full-screen loader, the review widget would be
  // unmounted by its own request and remounted forever — pumpAndSettle would
  // never settle.
  group('PartnerOnboardingScreen review stage', () {
    testWidgets('settles after opening review instead of reloading forever',
        (tester) async {
      repo.fleet = [_vehicle(id: 'vh-1', displayName: 'Toyota Innova Crysta')];
      // Longer than a 16ms frame, so the in-flight request is visible to the
      // shell — exactly the window in which the bug tears the stage down.
      repo.listFleetDelay = const Duration(milliseconds: 80);

      await tester.pumpWidget(
        _host(
          [partnerRepositoryProvider.overrideWithValue(repo)],
          const PartnerOnboardingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final reloadsBefore =
          repo.calls.where((c) => c == 'listFleet').length;

      ProviderScope.containerOf(
        tester.element(find.byType(PartnerOnboardingScreen)),
      ).read(partnerOnboardingProvider.notifier).goToReview();

      // Pump fixed 16ms frames rather than pumpAndSettle: stepping the clock a
      // whole request at a time would coalesce both states into one frame and
      // hide the bug. At frame granularity the request count climbs every frame
      // when the stage is being unmounted by its own reload.
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      final reloads = repo.calls.where((c) => c == 'listFleet').length -
          reloadsBefore;
      expect(reloads, lessThanOrEqualTo(2));
      expect(find.text('Submit for Verification'), findsOneWidget);
      expect(find.text('Loading your partner desk…'), findsNothing);
      expect(find.textContaining('Toyota Innova Crysta'), findsWidgets);
    });
  });

  // The server rejects a tariff whose components contradict each other
  // (assertSaneTariff). The form mirrors those rules so a partner gets told
  // without burning a round-trip.
  group('PartnerVehiclePricingScreen tariff consistency', () {
    // Field order inside the pricing ListView.
    const localIdx = 1, perKmIdx = 2, fullDayIdx = 5, outstationKmIdx = 8;

    Future<void> pumpPricing(WidgetTester tester) async {
      // A tall surface keeps every field built, so index lookups are stable.
      tester.view.physicalSize = const Size(1200, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          [partnerRepositoryProvider.overrideWithValue(repo)],
          // A Scaffold supplies the Material ancestor the form fields need.
          Scaffold(
            body: PartnerVehiclePricingScreen(
              vehicle: _vehicle(id: 'vh-1', displayName: 'Toyota Innova Crysta'),
              existing: const [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder fieldAt(int i) => find.byType(TextFormField).at(i);

    testWidgets('a full day below the local package is refused locally',
        (tester) async {
      await pumpPricing(tester);

      // ₹2000 clears the per-field floor (₹1000) but undercuts the ₹4500
      // local package — exactly the case only the cross-field rule catches.
      await tester.enterText(fieldAt(localIdx), '4500');
      await tester.enterText(fieldAt(perKmIdx), '15');
      await tester.enterText(fieldAt(fullDayIdx), '2000');
      await tester.tap(find.text('Submit Tariff for Review'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('cannot be lower than the local package'),
        findsOneWidget,
      );
      // Nothing was sent: the contradictory tariff never left the device.
      expect(repo.calls, isNot(contains('submitTariff')));
    });

    testWidgets('an outstation rate below the local per-km is refused locally',
        (tester) async {
      await pumpPricing(tester);

      await tester.enterText(fieldAt(localIdx), '4500');
      await tester.enterText(fieldAt(perKmIdx), '15');
      await tester.enterText(fieldAt(fullDayIdx), '9500');
      await tester.enterText(fieldAt(outstationKmIdx), '5');
      await tester.tap(find.text('Submit Tariff for Review'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('cannot be lower than the local per-km rate'),
        findsOneWidget,
      );
      expect(repo.calls, isNot(contains('submitTariff')));
    });

    testWidgets('editing a field clears the contradiction warning',
        (tester) async {
      await pumpPricing(tester);

      await tester.enterText(fieldAt(localIdx), '4500');
      await tester.enterText(fieldAt(perKmIdx), '15');
      await tester.enterText(fieldAt(fullDayIdx), '2000');
      await tester.tap(find.text('Submit Tariff for Review'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('cannot be lower than the local package'),
        findsOneWidget,
      );

      await tester.enterText(fieldAt(fullDayIdx), '9500');
      await tester.pumpAndSettle();

      expect(
        find.textContaining('cannot be lower than the local package'),
        findsNothing,
      );
    });
  });
}
