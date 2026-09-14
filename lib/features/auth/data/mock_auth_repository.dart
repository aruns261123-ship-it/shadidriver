// ============================================================
// ⚠️  DEVELOPMENT / MOCK IMPLEMENTATION — NOT PRODUCTION CODE ⚠️
// ============================================================
// This file is the mock authentication repository used during development only.
// It simulates the OTP flow locally without any real backend or SMS delivery.
//
// REMOVAL CHECKLIST when connecting a real backend:
//  1. Replace `authRepositoryProvider` in auth_providers.dart with the real impl.
//  2. Delete this file.
//  3. Remove DevAuthPanel from the app.
//
// MOCK CREDENTIALS:
//  - Any 10-digit phone number is accepted.
//  - Universal OTP code: 000000
//  - Role-specific OTP codes: customer=111111, driver=222222, fleetOwner=333333,
//    operationsAdmin=444444, verificationAdmin=555555, financeAdmin=666666,
//    superAdmin=999999
//  - OTP expires after 5 minutes.
// ============================================================

import 'dart:async';
import 'dart:math';

import '../../../core/errors/failures.dart';
import '../../../core/result/result.dart';
import '../domain/entities/account_status.dart';
import '../domain/entities/auth_session.dart';
import '../domain/entities/user_role.dart';
import '../domain/repositories/auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  // In-memory session store — cleared on signOut, survives hot reload.
  AuthSession? _currentSession;

  // Tracks pending OTP sessions: sessionId → {role, phone, expiresAt}
  final Map<String, _MockOtpSession> _pendingOtpSessions = {};

  static const String _universalOtp = '000000';
  static const Map<UserRole, String> _roleOtpCodes = {
    UserRole.customer: '111111',
    UserRole.driver: '222222',
    UserRole.fleetOwner: '333333',
    UserRole.operationsAdmin: '444444',
    UserRole.verificationAdmin: '555555',
    UserRole.financeAdmin: '666666',
    UserRole.superAdmin: '999999',
  };

  /// Simulate a small network round-trip delay for realistic UX testing.
  Future<void> _simulateDelay() =>
      Future.delayed(const Duration(milliseconds: 800));

  @override
  Future<Result<String>> requestOtp({
    required String phoneNumber,
    required UserRole role,
  }) async {
    // NOTE: DO NOT log phoneNumber in production code. Safe here because
    // this is a mock with no real user data.
    await _simulateDelay();

    // Basic format check (mock only accepts 10-digit numbers without country code,
    // or +91 prefixed numbers).
    final normalized = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final isValid = RegExp(r'^(\+91)?[6-9]\d{9}$').hasMatch(normalized);
    if (!isValid) {
      return const Result.failure(
        ValidationFailure(
          'Please enter a valid 10-digit Indian mobile number.',
          code: 'INVALID_PHONE',
        ),
      );
    }

    final sessionId =
        'mock_session_${Random().nextInt(999999).toString().padLeft(6, '0')}';
    _pendingOtpSessions[sessionId] = _MockOtpSession(
      phoneNumber: normalized,
      role: role,
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );

    // MOCK: Log session ID (safe — it's a temporary dev identifier, not a credential)
    // ignore: avoid_print
    print('[MOCK AUTH] OTP session created: $sessionId for role: ${role.displayLabel}');
    // ignore: avoid_print
    print('[MOCK AUTH] Use OTP: $_universalOtp or role-specific: ${_roleOtpCodes[role]}');

    return Result.success(sessionId);
  }

  @override
  Future<Result<AuthSession>> verifyOtp({
    required String otpSessionId,
    required String otpCode,
  }) async {
    await _simulateDelay();

    final otpSession = _pendingOtpSessions[otpSessionId];
    if (otpSession == null) {
      return const Result.failure(
        UnauthorizedFailure('OTP session not found. Please request a new OTP.'),
      );
    }

    if (DateTime.now().isAfter(otpSession.expiresAt)) {
      _pendingOtpSessions.remove(otpSessionId);
      return Result.failure(
        const UnauthorizedFailure(
          'Your OTP has expired. Please request a new one.',
          'OTP_EXPIRED',
        ),
      );
    }

    final expectedOtps = [
      _universalOtp,
      _roleOtpCodes[otpSession.role],
    ].whereType<String>().toSet();

    if (!expectedOtps.contains(otpCode)) {
      return Result.failure(
        const UnauthorizedFailure(
          'The OTP you entered is incorrect. Please try again.',
          'INVALID_OTP',
        ),
      );
    }

    // OTP valid — create session.
    _pendingOtpSessions.remove(otpSessionId);
    final session = _buildMockSession(otpSession);
    _currentSession = session;

    return Result.success(session);
  }

  @override
  Future<Result<AuthSession?>> restoreSession() async {
    await Future.delayed(const Duration(milliseconds: 300));
    // In the mock, session only survives within the same app process.
    // A real impl reads from SecureSessionStorageImpl.
    return Result.success(_currentSession);
  }

  @override
  Future<Result<void>> signOut() async {
    await _simulateDelay();
    _currentSession = null;
    _pendingOtpSessions.clear();
    return const Result.success(null);
  }

  @override
  Future<Result<AuthSession>> refreshSession() async {
    await Future.delayed(const Duration(milliseconds: 200));
    final session = _currentSession;
    if (session == null) {
      return const Result.failure(
        UnauthorizedFailure('No active session to refresh.'),
      );
    }
    // Mock: always succeeds if a session exists.
    final refreshed = session.copyWith(issuedAt: DateTime.now());
    _currentSession = refreshed;
    return Result.success(refreshed);
  }

  // ---------------------------------------------------------------------------
  // Dev helpers
  // ---------------------------------------------------------------------------

  /// Force a specific role without going through OTP flow.
  /// ONLY for the DevAuthPanel — must never be called in production paths.
  Future<Result<AuthSession>> devSignInAsRole(UserRole role) async {
    await _simulateDelay();
    final session = AuthSession(
      userId: 'dev_user_${role.storageKey}',
      phone: '+91 98765 XXXXX',
      role: role,
      displayName: 'Dev ${role.displayLabel}',
      accountStatus: AccountStatus.active,
      issuedAt: DateTime.now(),
    );
    _currentSession = session;
    return Result.success(session);
  }

  /// Sign in as a suspended account for testing the suspended screen.
  Future<Result<AuthSession>> devSignInAsSuspended() async {
    await _simulateDelay();
    final session = AuthSession(
      userId: 'dev_suspended_user',
      phone: '+91 98765 XXXXX',
      role: UserRole.customer,
      displayName: 'Suspended User',
      accountStatus: AccountStatus.suspended,
      issuedAt: DateTime.now(),
    );
    _currentSession = session;
    return Result.success(session);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  AuthSession _buildMockSession(_MockOtpSession otpSession) {
    // Mask phone for display
    final raw = otpSession.phoneNumber.replaceFirst(RegExp(r'^\+91'), '');
    final maskedPhone = '+91 ${raw.substring(0, 5)} XXXXX';

    return AuthSession(
      userId: 'mock_${otpSession.role.storageKey}_${DateTime.now().millisecondsSinceEpoch}',
      phone: maskedPhone,
      role: otpSession.role,
      displayName: 'Mock ${otpSession.role.displayLabel}',
      accountStatus: AccountStatus.active,
      issuedAt: DateTime.now(),
    );
  }
}

class _MockOtpSession {
  final String phoneNumber;
  final UserRole role;
  final DateTime expiresAt;

  const _MockOtpSession({
    required this.phoneNumber,
    required this.role,
    required this.expiresAt,
  });
}
