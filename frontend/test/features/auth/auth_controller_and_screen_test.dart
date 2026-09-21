import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/core/security/secure_storage_service.dart';
import 'package:shadidriver/features/auth/data/mock_auth_repository.dart';
import 'package:shadidriver/features/auth/domain/entities/auth_state.dart';
import 'package:shadidriver/features/auth/domain/entities/user_role.dart';
import 'package:shadidriver/features/auth/presentation/controllers/auth_controller.dart';
import 'package:shadidriver/features/auth/presentation/login_screen.dart';

class InMemorySecureStorage implements SecureStorageService {
  final Map<String, String> _data = {};

  @override
  Future<bool> containsKey(String key) async => _data.containsKey(key);

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<void> deleteAll() async => _data.clear();

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;
}

void main() {
  group('AuthController Lifecycle Tests', () {
    late MockAuthRepository authRepo;
    late InMemorySecureStorage storage;
    late ProviderContainer container;

    setUp(() {
      authRepo = MockAuthRepository();
      storage = InMemorySecureStorage();
      container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepo),
          secureStorageProvider.overrideWithValue(storage),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is AuthUnknown', () {
      final state = container.read(authControllerProvider);
      expect(state, isA<AuthUnknown>());
    });

    test(
      'restoreSession transitions to Unauthenticated when clean start',
      () async {
        final controller = container.read(authControllerProvider.notifier);
        await controller.restoreSession();
        final state = container.read(authControllerProvider);
        expect(state, isA<Unauthenticated>());
      },
    );

    test('requestOtp transitions to OtpSent with masked phone', () async {
      final controller = container.read(authControllerProvider.notifier);
      final result = await controller.requestOtp(
        phoneNumber: '9876543210',
        role: UserRole.customer,
      );

      expect(result.isSuccess, isTrue);
      final state = container.read(authControllerProvider);
      expect(state, isA<OtpSent>());
      final otpSent = state as OtpSent;
      expect(otpSent.maskedPhone, contains('3210'));
      expect(otpSent.otpSessionId, isNotEmpty);
    });

    test('verifyOtp with valid code transitions to Authenticated', () async {
      final controller = container.read(authControllerProvider.notifier);
      final reqResult = await controller.requestOtp(
        phoneNumber: '9876543210',
        role: UserRole.customer,
      );
      final sessionId = reqResult.dataOrNull!;

      final verifyResult = await controller.verifyOtp(
        otpSessionId: sessionId,
        otpCode: '000000', // Universal mock code
      );

      expect(verifyResult.isSuccess, isTrue);
      final state = container.read(authControllerProvider);
      expect(state, isA<Authenticated>());
      final auth = state as Authenticated;
      expect(auth.session.role, equals(UserRole.customer));
    });

    test('verifyOtp with invalid code transitions to AuthError', () async {
      final controller = container.read(authControllerProvider.notifier);
      final reqResult = await controller.requestOtp(
        phoneNumber: '9876543210',
        role: UserRole.customer,
      );
      final sessionId = reqResult.dataOrNull!;

      final verifyResult = await controller.verifyOtp(
        otpSessionId: sessionId,
        otpCode: '999123', // Incorrect code
      );

      expect(verifyResult.isFailure, isTrue);
      final state = container.read(authControllerProvider);
      expect(state, isA<AuthError>());
      final authError = state as AuthError;
      expect(authError.kind, equals(AuthErrorKind.invalidOtp));
    });

    test('devLoginAsRole bypass logs directly into chosen role', () async {
      final controller = container.read(authControllerProvider.notifier);
      await controller.devLoginAsRole(UserRole.driver);

      final state = container.read(authControllerProvider);
      expect(state, isA<Authenticated>());
      final auth = state as Authenticated;
      expect(auth.session.role, equals(UserRole.driver));
    });

    test('signOut clears session and transitions to Unauthenticated', () async {
      final controller = container.read(authControllerProvider.notifier);
      await controller.devLoginAsRole(UserRole.customer);
      expect(container.read(authControllerProvider), isA<Authenticated>());

      await controller.signOut();
      expect(container.read(authControllerProvider), isA<Unauthenticated>());
    });
  });

  group('Sign Up Flow Tests', () {
    late MockAuthRepository authRepo;
    late InMemorySecureStorage storage;
    late ProviderContainer container;

    setUp(() {
      authRepo = MockAuthRepository();
      storage = InMemorySecureStorage();
      container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepo),
          secureStorageProvider.overrideWithValue(storage),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('signUp creates account and transitions to OtpSent', () async {
      final controller = container.read(authControllerProvider.notifier);
      final result = await controller.signUp(
        phoneNumber: '9765432109',
        displayName: 'Aarav Mehta',
        role: UserRole.customer,
      );

      expect(result.isSuccess, isTrue);
      final state = container.read(authControllerProvider);
      expect(state, isA<OtpSent>());
      final otpSent = state as OtpSent;
      expect(otpSent.maskedPhone, contains('2109'));
    });

    test(
      'signUp then verifyOtp authenticates with chosen role and name',
      () async {
        final controller = container.read(authControllerProvider.notifier);
        final req = await controller.signUp(
          phoneNumber: '9765432108',
          displayName: 'Aarav Mehta',
          role: UserRole.driver,
        );
        expect(req.isSuccess, isTrue);

        final verify = await controller.verifyOtp(
          otpSessionId: req.dataOrNull!,
          otpCode: '000000',
        );
        expect(verify.isSuccess, isTrue);

        final state = container.read(authControllerProvider);
        expect(state, isA<Authenticated>());
        final session = (state as Authenticated).session;
        expect(session.role, equals(UserRole.driver));
        expect(session.displayName, equals('Aarav Mehta'));
      },
    );

    test('signUp rejects already registered phone number', () async {
      final controller = container.read(authControllerProvider.notifier);

      // Register a fresh account first, then attempt the same number again.
      final first = await controller.signUp(
        phoneNumber: '9765432107',
        displayName: 'Original User',
      );
      expect(first.isSuccess, isTrue);

      final duplicate = await controller.signUp(
        phoneNumber: '9765432107',
        displayName: 'Duplicate User',
      );

      expect(duplicate.isFailure, isTrue);
      expect(
        duplicate.failureOrNull?.code,
        equals('PHONE_ALREADY_REGISTERED'),
      );
    });

    test('signUp rejects admin role registration', () async {
      final controller = container.read(authControllerProvider.notifier);
      final result = await controller.signUp(
        phoneNumber: '9765432106',
        displayName: 'Sneaky Admin',
        role: UserRole.superAdmin,
      );

      expect(result.isFailure, isTrue);
      expect(
        result.failureOrNull?.code,
        equals('ADMIN_REGISTRATION_PROHIBITED'),
      );
    });

    test('signUp rejects too-short display name', () async {
      final controller = container.read(authControllerProvider.notifier);
      final result = await controller.signUp(
        phoneNumber: '9765432105',
        displayName: 'A',
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.code, equals('INVALID_NAME'));
    });

    test(
      'signUp account can sign in again on subsequent login',
      () async {
        final controller = container.read(authControllerProvider.notifier);

        // Register the new account first.
        final signUpResult = await controller.signUp(
          phoneNumber: '9765432104',
          displayName: 'Aarav Mehta',
          role: UserRole.customer,
        );
        expect(signUpResult.isSuccess, isTrue);
        await controller.verifyOtp(
          otpSessionId: signUpResult.dataOrNull!,
          otpCode: '000000',
        );
        await controller.signOut();

        // Sign back in through the normal login flow.
        final loginResult = await controller.requestOtp(
          phoneNumber: '9765432104',
        );
        expect(loginResult.isSuccess, isTrue);
        final verify = await controller.verifyOtp(
          otpSessionId: loginResult.dataOrNull!,
          otpCode: '000000',
        );
        expect(verify.isSuccess, isTrue);

        final state = container.read(authControllerProvider);
        expect(state, isA<Authenticated>());
        final session = (state as Authenticated).session;
        expect(session.role, equals(UserRole.customer));
        expect(session.displayName, equals('Aarav Mehta'));
      },
    );
  });

  group('LoginScreen Widget Tests', () {
    testWidgets(
      'renders brand crest, phone input, and no dev bypass or role chips',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: LoginScreen())),
        );

        await tester.pump();

        // Brand headers
        expect(find.text('ShadiDriver'), findsOneWidget);
        expect(find.text('Royal Chauffeur Service'), findsOneWidget);
        expect(find.text('Welcome to ShadiDriver'), findsOneWidget);
        expect(find.text('Sign in or create your account'), findsOneWidget);

        // Phone Input & CTA
        expect(find.text('🇮🇳 +91'), findsOneWidget);
        expect(find.text('Continue'), findsOneWidget);

        // Mode toggle defaults to Sign In
        expect(find.text('Sign In'), findsOneWidget);
        expect(find.text('Create Account'), findsOneWidget);
        expect(find.text('Full name'), findsNothing);

        // Production invariant: No role selector chips
        expect(find.text('Host / Guest'), findsNothing);
        expect(find.text('Chauffeur'), findsNothing);
        expect(find.text('Operations'), findsNothing);

        // Production invariant: No Developer Quick Bypass
        expect(find.text('Developer Quick Bypass (1-Tap)'), findsNothing);
        expect(find.text('Developer Quick Bypass'), findsNothing);
      },
    );

    testWidgets('toggling to Create Account reveals sign-up form', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginScreen())),
      );

      await tester.pump();
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      // Sign-up form fields ("Create Account" appears as both toggle label
      // and submit button, so assert presence rather than uniqueness)
      expect(find.text('Create your account'), findsOneWidget);
      expect(find.text('Full name'), findsOneWidget);
      expect(find.text('I am joining as'), findsOneWidget);
      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('Chauffeur'), findsOneWidget);
      expect(find.text('Create Account'), findsWidgets);

      // Phone field still present in sign-up mode
      expect(find.text('🇮🇳 +91'), findsOneWidget);

      // Back to Sign In restores login form
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to ShadiDriver'), findsOneWidget);
      expect(find.text('Full name'), findsNothing);
    });
  });
}
