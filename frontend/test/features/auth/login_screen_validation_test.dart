import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/core/errors/failures.dart';
import 'package:shadidriver/core/result/result.dart';
import 'package:shadidriver/core/security/secure_storage_service.dart';
import 'package:shadidriver/core/widgets/shadi_primary_button.dart';
import 'package:shadidriver/features/auth/data/mock_auth_repository.dart';
import 'package:shadidriver/features/auth/domain/entities/user_role.dart';
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

/// Repository whose signUp always returns a mapped backend validation failure.
class _RejectingAuthRepository extends MockAuthRepository {
  _RejectingAuthRepository() : super(null, false);

  @override
  Future<Result<String>> signUp({
    required String phoneNumber,
    required String displayName,
    UserRole role = UserRole.customer,
  }) async {
    return const Result.failure(
      ValidationFailure('Enter a valid mobile number.', code: 'VALIDATION_FAILED'),
    );
  }
}

void main() {
  Future<void> pumpLoginScreen(
    WidgetTester tester, {
    required MockAuthRepository repo,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Create Account').first);
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    final button = find.byType(ShadiPrimaryButton);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('rejects a display name shorter than 2 characters', (tester) async {
    await pumpLoginScreen(tester, repo: MockAuthRepository(null, false));

    await tester.enterText(find.byType(TextField).at(0), 'A');
    await tester.enterText(find.byType(TextField).at(1), '9876543210');
    await submit(tester);

    expect(find.text('Name must be at least 2 characters.'), findsOneWidget);
  });

  testWidgets('rejects an invalid mobile number', (tester) async {
    await pumpLoginScreen(tester, repo: MockAuthRepository(null, false));

    await tester.enterText(find.byType(TextField).at(0), 'Aarav Mehta');
    await tester.enterText(find.byType(TextField).at(1), '12345');
    await submit(tester);

    expect(find.text('Enter a valid mobile number.'), findsOneWidget);
  });

  testWidgets('valid registration transitions to the OTP verification step', (
    tester,
  ) async {
    await pumpLoginScreen(tester, repo: MockAuthRepository(null, false));

    await tester.enterText(find.byType(TextField).at(0), 'Aarav Mehta');
    await tester.enterText(find.byType(TextField).at(1), '9876500099');
    await submit(tester);

    expect(find.text('Verify your number'), findsOneWidget);
    expect(find.textContaining('Enter the 6-digit code'), findsOneWidget);
  });

  testWidgets('surfaces the mapped backend validation error message', (
    tester,
  ) async {
    await pumpLoginScreen(tester, repo: _RejectingAuthRepository());

    await tester.enterText(find.byType(TextField).at(0), 'Aarav Mehta');
    await tester.enterText(find.byType(TextField).at(1), '9876543210');
    await submit(tester);

    expect(find.text('Enter a valid mobile number.'), findsOneWidget);
  });
}
