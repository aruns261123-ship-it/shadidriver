import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/router/app_router.dart';
import 'package:shadidriver/app/router/route_paths.dart';
import 'package:shadidriver/core/result/result.dart';
import 'package:shadidriver/core/widgets/shadi_text_field.dart';
import 'package:shadidriver/features/drivers/data/mock_driver_profile_repository.dart';
import 'package:shadidriver/features/drivers/domain/entities/driver_profile.dart';
import 'package:shadidriver/features/drivers/presentation/controllers/driver_profile_controller.dart';
import 'package:shadidriver/features/drivers/presentation/driver_account_center_screen.dart';
import 'package:shadidriver/features/drivers/presentation/driver_edit_profile_screen.dart';
import 'package:shadidriver/features/profile/data/mock_profile_photo_service.dart';

import '../../helpers/mock_env.dart';

void main() {
  setUp(() {
    MockDriverProfileRepository.resetSession();
  });

  Widget buildTestApp({
    required String initialLocation,
    ProviderContainer? container,
  }) {
    final router = createShadiRouter(
      initialLocation: initialLocation,
      navigatorKey: GlobalKey<NavigatorState>(),
    );
    if (container != null) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      );
    }
    return ProviderScope(
      overrides: mockModeOverrides(),
      child: MaterialApp.router(routerConfig: router),
    );
  }

  void configurePhoneDimensions(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Finder findField(String label) {
    return find.descendant(
      of: find.widgetWithText(ShadiTextField, label),
      matching: find.byType(TextFormField),
    );
  }

  Future<void> enterField(
    WidgetTester tester,
    String label,
    String text,
  ) async {
    final field = findField(label);
    await tester.ensureVisible(field);
    await tester.pump();
    await tester.enterText(field, text);
  }

  Future<void> settleApp(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  group('Chauffeur Profile Save & Complete Profile Navigation Tests', () {
    // -------------------------------------------------------------------------
    // Scenario 1: Edit chauffeur profile with valid data -> save succeeds
    // -------------------------------------------------------------------------
    testWidgets(
      'Scenario 1: Edit chauffeur profile with valid data triggers successful save snackbar',
      (tester) async {
        configurePhoneDimensions(tester);

        await tester.pumpWidget(
          buildTestApp(initialLocation: RoutePaths.driverProfileEdit),
        );
        await settleApp(tester);

        // Screen is loaded with initial values
        expect(find.text('Edit Chauffeur Details'), findsOneWidget);

        // Edit full name
        final nameField = findField('Full Name *');
        expect(nameField, findsOneWidget);
        await tester.enterText(nameField, 'Vikram Singh Rathore');

        // Edit bio
        final bioField = findField('Chauffeur Bio *');
        await tester.enterText(
          bioField,
          'Elite ceremonial chauffeur with extensive VIP and royal Baraat procession expertise.',
        );

        // Edit operating area
        final areaField = findField('Primary Operating Area / Route *');
        await tester.enterText(areaField, 'Udaipur Palace & Jaipur Highway');

        // Scroll to save button and tap
        final saveButton = find.text('Save Profile');
        await tester.ensureVisible(saveButton);
        await tester.pumpAndSettle();
        await tester.tap(saveButton);

        // Settle save and SnackBar
        await settleApp(tester);

        // Verify success snackbar
        expect(find.text('Profile saved successfully'), findsOneWidget);
      },
    );

    // -------------------------------------------------------------------------
    // Scenario 2: Save persists edited profile in repository (_sessionProfiles)
    // -------------------------------------------------------------------------
    testWidgets(
      'Scenario 2: Save persists edited profile into MockDriverProfileRepository session',
      (tester) async {
        configurePhoneDimensions(tester);

        await tester.pumpWidget(
          buildTestApp(initialLocation: RoutePaths.driverProfileEdit),
        );
        await settleApp(tester);

        await enterField(tester, 'Full Name *', 'Karanveer Oberoi');
        await enterField(
          tester,
          'Chauffeur Bio *',
          '15 years leading vintage convoy processions for high-profile weddings.',
        );
        await enterField(
          tester,
          'Primary Operating Area / Route *',
          'South Delhi & Aerocity NCR',
        );
        await enterField(tester, 'Total Experience (Yrs) *', '15');
        await enterField(tester, 'Wedding Exp (Yrs) *', '12');
        final saveBtn = find.text('Save Profile');
        await tester.ensureVisible(saveBtn);
        await tester.pumpAndSettle();
        await tester.tap(saveBtn);
        await settleApp(tester);

        // Verify directly in repository session
        final profile = MockDriverProfileRepository.getSessionProfile('d1');
        expect(profile, isNotNull);
        expect(profile!.fullName, equals('Karanveer Oberoi'));
        expect(
          profile.bio,
          equals(
            '15 years leading vintage convoy processions for high-profile weddings.',
          ),
        );
        expect(profile.operatingArea, equals('South Delhi & Aerocity NCR'));
        expect(profile.experienceYears, equals(15));
        expect(profile.weddingExperienceYears, equals(12));
      },
    );

    // -------------------------------------------------------------------------
    // Scenario 3: After save, navigates to Complete Chauffeur Profile
    // -------------------------------------------------------------------------
    testWidgets(
      'Scenario 3: After save, navigates immediately to Complete Chauffeur Profile screen',
      (tester) async {
        configurePhoneDimensions(tester);

        await tester.pumpWidget(
          buildTestApp(initialLocation: RoutePaths.driverProfileEdit),
        );
        await settleApp(tester);

        final saveBtn = find.text('Save Profile');
        await tester.ensureVisible(saveBtn);
        await tester.pumpAndSettle();
        await tester.tap(saveBtn);
        await settleApp(tester);

        // Verify navigation landed on Chauffeur Profile
        expect(find.byType(DriverAccountCenterScreen), findsOneWidget);
        expect(find.text('Chauffeur Profile'), findsOneWidget);
        expect(find.text('Fleet & Duty Credentials'), findsOneWidget);
      },
    );

    // -------------------------------------------------------------------------
    // Scenario 4: Complete Chauffeur Profile displays newly saved values
    // -------------------------------------------------------------------------
    testWidgets(
      'Scenario 4: Complete Chauffeur Profile displays newly saved values',
      (tester) async {
        configurePhoneDimensions(tester);

        await tester.pumpWidget(
          buildTestApp(initialLocation: RoutePaths.driverProfileEdit),
        );
        await settleApp(tester);

        // Enter distinct new details
        await enterField(tester, 'Full Name *', 'Harshvardhan Rathore');
        await enterField(
          tester,
          'Chauffeur Bio *',
          'Specialist in luxury royal wedding fleets and convoy timing precision.',
        );
        await enterField(
          tester,
          'Primary Operating Area / Route *',
          'Jaipur & Udaipur Heritage Routes',
        );
        await enterField(tester, 'Total Experience (Yrs) *', '14');
        await enterField(tester, 'Wedding Exp (Yrs) *', '10');

        final saveBtn = find.text('Save Profile');
        await tester.ensureVisible(saveBtn);
        await tester.pumpAndSettle();
        await tester.tap(saveBtn);
        await settleApp(tester);

        // Check Complete Chauffeur Profile screen contents
        expect(find.text('Harshvardhan Rathore'), findsOneWidget);
        expect(
          find.text('14 Yrs Total Exp • 10 Yrs Wedding Exp'),
          findsOneWidget,
        );
        expect(find.text('Jaipur & Udaipur Heritage Routes'), findsOneWidget);
        expect(
          find.text(
            'Specialist in luxury royal wedding fleets and convoy timing precision.',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('Languages: Hindi, English'),
          findsOneWidget,
        );
        expect(find.text('CHAUFFEUR'), findsOneWidget);
        expect(find.text('Profile Completion'), findsOneWidget);
      },
    );

    // -------------------------------------------------------------------------
    // Scenario 5: Reopening profile displays saved values
    // -------------------------------------------------------------------------
    testWidgets(
      'Scenario 5: Reopening Complete Chauffeur Profile displays persisted values across screen reloads',
      (tester) async {
        configurePhoneDimensions(tester);

        // Pre-save an update via repository session
        MockDriverProfileRepository();
        final current = MockDriverProfileRepository.getSessionProfile('d1')!;
        MockDriverProfileRepository.setSessionProfile(
          current.copyWithEditableFields(
            fullName: 'Devendra Shekhawat',
            bio:
                'Master of baraat ceremonies and vintage luxury fleet handling.',
            operatingArea: 'Jodhpur & Jaisalmer Forts',
            experienceYears: 16,
            weddingExperienceYears: 11,
            languages: const ['Hindi', 'Rajasthani', 'English'],
          ),
        );

        // Open Complete Chauffeur Profile directly
        await tester.pumpWidget(
          buildTestApp(initialLocation: RoutePaths.driverProfile),
        );
        await settleApp(tester);

        expect(find.text('Devendra Shekhawat'), findsOneWidget);
        expect(
          find.text('16 Yrs Total Exp • 11 Yrs Wedding Exp'),
          findsOneWidget,
        );
        expect(find.text('Jodhpur & Jaisalmer Forts'), findsOneWidget);
        expect(
          find.text('Languages: Hindi, Rajasthani, English'),
          findsOneWidget,
        );
      },
    );

    // -------------------------------------------------------------------------
    // Scenario 6: Invalid required field -> save blocked with field-level validation message
    // -------------------------------------------------------------------------
    testWidgets(
      'Scenario 6: Invalid fields block save with clear validation messages',
      (tester) async {
        configurePhoneDimensions(tester);

        await tester.pumpWidget(
          buildTestApp(initialLocation: RoutePaths.driverProfileEdit),
        );
        await settleApp(tester);

        // 1. Clear Name (< 2 chars)
        await enterField(tester, 'Full Name *', 'A');

        // 2. Clear Bio (< 10 chars)
        await enterField(tester, 'Chauffeur Bio *', 'Short');

        // 3. Clear Operating Area
        await enterField(tester, 'Primary Operating Area / Route *', '');

        // 4. Invalid Total Experience (0)
        await enterField(tester, 'Total Experience (Yrs) *', '0');

        // 5. Wedding Exp > Total Exp
        await enterField(tester, 'Wedding Exp (Yrs) *', '5');

        // Tap Save Profile
        final saveBtn = find.text('Save Profile');
        await tester.ensureVisible(saveBtn);
        await tester.pumpAndSettle();
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        // Verify field-level validation errors
        expect(
          find.text('Full Name is required (at least 2 characters)'),
          findsOneWidget,
        );
        expect(
          find.text('Chauffeur Bio is required (at least 10 characters)'),
          findsOneWidget,
        );
        expect(find.text('Primary Operating Area is required'), findsOneWidget);
        expect(find.text('Must be >= 1 year'), findsOneWidget);
        expect(find.text('Cannot exceed Total (0)'), findsOneWidget);
        expect(
          find.text('Please correct the highlighted fields before saving.'),
          findsOneWidget,
        );

        // Verify we are still on the edit screen and did NOT navigate
        expect(find.byType(DriverEditProfileScreen), findsOneWidget);
        expect(find.byType(DriverAccountCenterScreen), findsNothing);

        // Deselect all languages test
        // Deselect Hindi, English, Punjabi
        await tester.tap(find.widgetWithText(FilterChip, 'Hindi'));
        await tester.tap(find.widgetWithText(FilterChip, 'English'));
        await tester.tap(find.widgetWithText(FilterChip, 'Punjabi'));
        await tester.pumpAndSettle();

        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        expect(
          find.text('Please select at least one spoken language.'),
          findsOneWidget,
        );
      },
    );

    // -------------------------------------------------------------------------
    // Scenario 7: Double-tap Save -> only single save triggered
    // -------------------------------------------------------------------------
    testWidgets(
      'Scenario 7: Double-tap Save triggers only single save without multiple invocations',
      (tester) async {
        configurePhoneDimensions(tester);

        int updateCount = 0;
        final mockRepo = _CountingDriverProfileRepository(() => updateCount++);

        final container = ProviderContainer(
          overrides: [
          ...mockModeOverrides(),
            driverProfileControllerProvider('d1').overrideWith((ref) {
              return DriverProfileController(
                repository: mockRepo,
                photoService: MockProfilePhotoService(),
                driverId: 'd1',
              );
            }),
          ],
        );

        await tester.pumpWidget(
          buildTestApp(
            initialLocation: RoutePaths.driverProfileEdit,
            container: container,
          ),
        );
        await settleApp(tester);

        final saveBtn = find.text('Save Profile');
        await tester.ensureVisible(saveBtn);
        await tester.pumpAndSettle();

        // Double tap rapidly
        await tester.tap(saveBtn);
        await tester.tap(saveBtn);

        await settleApp(tester);

        expect(updateCount, equals(1));
      },
    );

    // -------------------------------------------------------------------------
    // Scenario 8: Verification status remains read-only
    // -------------------------------------------------------------------------
    testWidgets(
      'Scenario 8: Verification status remains strictly read-only and compliance locked',
      (tester) async {
        configurePhoneDimensions(tester);

        await tester.pumpWidget(
          buildTestApp(initialLocation: RoutePaths.driverProfileEdit),
        );
        await settleApp(tester);

        // Verify compliance lock text on edit screen
        expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
        expect(
          find.textContaining('Verification status (UNDER_REVIEW)'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'managed by Compliance and cannot be self-modified',
          ),
          findsOneWidget,
        );

        // Save new profile
        final saveBtn = find.text('Save Profile');
        await tester.ensureVisible(saveBtn);
        await tester.pumpAndSettle();
        await tester.tap(saveBtn);
        await settleApp(tester);

        // Check Complete Chauffeur Profile has unchanged verification status
        expect(find.text('UNDER REVIEW'), findsOneWidget);
        expect(find.text('Verification Status'), findsOneWidget);
        expect(
          find.textContaining('Driver verification is conducted independently'),
          findsOneWidget,
        );
      },
    );

    // -------------------------------------------------------------------------
    // Scenario 9: Assigned Fleet remains read-only
    // -------------------------------------------------------------------------
    testWidgets(
      'Scenario 9: Assigned Fleet remains strictly read-only and preserved across edits',
      (tester) async {
        configurePhoneDimensions(tester);

        await tester.pumpWidget(
          buildTestApp(initialLocation: RoutePaths.driverProfileEdit),
        );
        await settleApp(tester);

        // Notice mentions assigned fleet
        expect(
          find.textContaining('Assigned Fleet (ASSIGNED_AUDI_A6)'),
          findsOneWidget,
        );

        // Tap Save
        final saveBtn = find.text('Save Profile');
        await tester.ensureVisible(saveBtn);
        await tester.pumpAndSettle();
        await tester.tap(saveBtn);
        await settleApp(tester);

        // On complete profile, fleet credentials show unchanged status
        expect(find.text('Assigned Vehicle'), findsOneWidget);
        expect(
          find.textContaining('ASSIGNED_AUDI_A6 • Inspected for Ceremonies'),
          findsOneWidget,
        );
      },
    );

    // -------------------------------------------------------------------------
    // Scenario 10: "Edit Profile" from Complete Chauffeur Profile opens edit screen
    // -------------------------------------------------------------------------
    testWidgets(
      'Scenario 10: Edit Profile button from Complete Profile opens edit screen with current values',
      (tester) async {
        configurePhoneDimensions(tester);

        await tester.pumpWidget(
          buildTestApp(initialLocation: RoutePaths.driverProfile),
        );
        await settleApp(tester);

        expect(find.byType(DriverAccountCenterScreen), findsOneWidget);

        // Find and tap Edit Profile button
        final editProfileBtn = find.widgetWithText(TextButton, 'Edit Profile');
        expect(editProfileBtn, findsOneWidget);
        await tester.tap(editProfileBtn);
        await settleApp(tester);

        // Verify edit screen is displayed with current chauffeur details
        expect(find.byType(DriverEditProfileScreen), findsOneWidget);
        expect(find.text('Edit Chauffeur Details'), findsOneWidget);
        expect(find.text('Rajesh Kumar'), findsOneWidget);
        expect(find.text('Delhi NCR & Jaipur Highway'), findsOneWidget);
      },
    );

    // -------------------------------------------------------------------------
    // Scenario 11: Back navigation from Edit Profile does not create route loop
    // -------------------------------------------------------------------------
    testWidgets(
      'Scenario 11: Back navigation from Edit Profile returns safely without loop',
      (tester) async {
        configurePhoneDimensions(tester);

        // Start from Complete Profile
        await tester.pumpWidget(
          buildTestApp(initialLocation: RoutePaths.driverProfile),
        );
        await settleApp(tester);

        // Tap Edit Profile
        await tester.tap(find.widgetWithText(TextButton, 'Edit Profile'));
        await settleApp(tester);
        expect(find.byType(DriverEditProfileScreen), findsOneWidget);

        // Tap Back button in AppBar
        final backBtn = find.byIcon(Icons.arrow_back_rounded);
        expect(backBtn, findsOneWidget);
        await tester.tap(backBtn);
        await settleApp(tester);

        // Safely returned to Chauffeur Profile
        expect(find.byType(DriverAccountCenterScreen), findsOneWidget);
        expect(find.byType(DriverEditProfileScreen), findsNothing);

        // Now test deep link direct to Edit Profile and tap Cancel
        await tester.pumpWidget(
          buildTestApp(initialLocation: RoutePaths.driverProfileEdit),
        );
        await settleApp(tester);
        expect(find.byType(DriverEditProfileScreen), findsOneWidget);

        final cancelBtn = find.text('Cancel');
        await tester.ensureVisible(cancelBtn);
        await tester.pumpAndSettle();
        await tester.tap(cancelBtn);
        await settleApp(tester);

        // Deep-linked direct entry navigated safely to driverProfile via fallback
        expect(find.byType(DriverAccountCenterScreen), findsOneWidget);
      },
    );
  });
}

class _CountingDriverProfileRepository extends MockDriverProfileRepository {
  final VoidCallback onUpdate;

  _CountingDriverProfileRepository(this.onUpdate);

  @override
  Future<Result<DriverProfile>> updateProfile(DriverProfile profile) async {
    onUpdate();
    return super.updateProfile(profile);
  }
}
