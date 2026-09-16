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
import '../../../core/security/secure_storage_service.dart';
import '../domain/entities/account_status.dart';
import '../domain/entities/auth_session.dart';
import '../domain/entities/user_role.dart';
import '../domain/repositories/auth_repository.dart';

class MockAuthAccount {
  final String phone;
  final UserRole role;
  final AccountStatus accountStatus;
  final String displayName;
  final String? customOtp;

  const MockAuthAccount({
    required this.phone,
    required this.role,
    required this.accountStatus,
    required this.displayName,
    this.customOtp,
  });
}

class MockAuthRepository implements AuthRepository {
  final SecureStorageService? _storage;

  // In-memory session store — cleared on signOut.
  AuthSession? _currentSession;

  // Tracks pending OTP sessions: sessionId → _MockOtpSession
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

  static final Map<String, MockAuthAccount> _registeredAccounts = {
    '9876543210': const MockAuthAccount(
      phone: '9876543210',
      role: UserRole.customer,
      accountStatus: AccountStatus.active,
      displayName: 'Kabir Sharma',
      customOtp: '111111',
    ),
    '9810000001': const MockAuthAccount(
      phone: '9810000001',
      role: UserRole.customer,
      accountStatus: AccountStatus.active,
      displayName: 'Kabir Sharma',
      customOtp: '111111',
    ),
    '9810000002': const MockAuthAccount(
      phone: '9810000002',
      role: UserRole.driver,
      accountStatus: AccountStatus.active,
      displayName: 'Rajesh Singh',
      customOtp: '222222',
    ),
    '9876500002': const MockAuthAccount(
      phone: '9876500002',
      role: UserRole.driver,
      accountStatus: AccountStatus.active,
      displayName: 'Rajesh Singh',
      customOtp: '222222',
    ),
    '9810000003': const MockAuthAccount(
      phone: '9810000003',
      role: UserRole.operationsAdmin,
      accountStatus: AccountStatus.active,
      displayName: 'Vikram Malhotra',
      customOtp: '444444',
    ),
    '9876500003': const MockAuthAccount(
      phone: '9876500003',
      role: UserRole.operationsAdmin,
      accountStatus: AccountStatus.active,
      displayName: 'Vikram Malhotra',
      customOtp: '444444',
    ),
    '9810000004': const MockAuthAccount(
      phone: '9810000004',
      role: UserRole.customer,
      accountStatus: AccountStatus.profileIncomplete,
      displayName: 'New Customer',
    ),
    '9810000005': const MockAuthAccount(
      phone: '9810000005',
      role: UserRole.driver,
      accountStatus: AccountStatus.profileIncomplete,
      displayName: 'New Chauffeur Applicant',
    ),
    '9810000006': const MockAuthAccount(
      phone: '9810000006',
      role: UserRole.customer,
      accountStatus: AccountStatus.suspended,
      displayName: 'Suspended User',
    ),
  };

  final bool simulateDelays;

  MockAuthRepository([this._storage, this.simulateDelays = true]);

  Future<void> _simulateDelay([int ms = 300]) {
    if (!simulateDelays || ms <= 0) return Future.value();
    return Future.delayed(Duration(milliseconds: ms));
  }

  static bool _isAdminRole(UserRole role) => switch (role) {
    UserRole.operationsAdmin ||
    UserRole.verificationAdmin ||
    UserRole.financeAdmin ||
    UserRole.superAdmin => true,
    _ => false,
  };

  @override
  Future<Result<String>> requestOtp({
    required String phoneNumber,
    UserRole? role,
  }) async {
    await _simulateDelay();

    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final raw10 = digits.length > 10 ? digits.substring(digits.length - 10) : digits;

    final isValid = RegExp(r'^[6-9]\d{9}$').hasMatch(raw10);
    if (!isValid) {
      return const Result.failure(
        ValidationFailure(
          'Please enter a valid 10-digit Indian mobile number.',
          code: 'INVALID_PHONE',
        ),
      );
    }

    final registered = _registeredAccounts[raw10];

    // Public admin registration prohibition
    if (role != null && _isAdminRole(role) && (registered == null || !_isAdminRole(registered.role))) {
      return const Result.failure(
        UnauthorizedFailure(
          'Admin accounts cannot be created via public registration.',
          'ADMIN_REGISTRATION_PROHIBITED',
        ),
      );
    }

    final UserRole resolvedRole;
    final AccountStatus resolvedStatus;
    final String resolvedDisplayName;
    final String? resolvedCustomOtp;

    if (registered != null) {
      resolvedRole = role ?? registered.role;
      resolvedStatus = registered.accountStatus;
      resolvedDisplayName = registered.displayName;
      resolvedCustomOtp = registered.customOtp;
    } else {
      resolvedRole = role ?? UserRole.customer;
      resolvedStatus = AccountStatus.active;
      resolvedDisplayName = 'ShadiDriver Guest';
      resolvedCustomOtp = null;
    }

    final sessionId =
        'mock_session_${Random().nextInt(999999).toString().padLeft(6, '0')}';
    _pendingOtpSessions[sessionId] = _MockOtpSession(
      phoneNumber: raw10,
      role: resolvedRole,
      accountStatus: resolvedStatus,
      displayName: resolvedDisplayName,
      customOtp: resolvedCustomOtp,
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );

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
      return const Result.failure(
        UnauthorizedFailure(
          'Your OTP has expired. Please request a new one.',
          'OTP_EXPIRED',
        ),
      );
    }

    final expectedOtps = [
      _universalOtp,
      if (otpSession.customOtp != null) otpSession.customOtp!,
      _roleOtpCodes[otpSession.role],
    ].whereType<String>().toSet();

    if (!expectedOtps.contains(otpCode)) {
      return const Result.failure(
        UnauthorizedFailure(
          'The OTP you entered is incorrect. Please try again.',
          'INVALID_OTP',
        ),
      );
    }

    _pendingOtpSessions.remove(otpSessionId);
    final session = _buildMockSession(otpSession);
    _currentSession = session;

    await _persistSession(session);

    return Result.success(session);
  }

  @override
  Future<Result<AuthSession?>> restoreSession() async {
    await _simulateDelay(100);

    if (_currentSession != null) {
      return Result.success(_currentSession);
    }

    if (_storage != null) {
      final userId = await _storage.read('auth_user_id');
      if (userId != null && userId.isNotEmpty) {
        final roleKey = await _storage.read('auth_role');
        final phone = await _storage.read('auth_phone') ?? '';
        final statusKey = await _storage.read('auth_status');
        final displayName = await _storage.read('auth_display_name');

        final role = UserRole.fromStorageKey(roleKey);
        final status = AccountStatus.fromStorageKey(statusKey);

        final restored = AuthSession(
          userId: userId,
          phone: phone,
          role: role ?? UserRole.customer,
          displayName: displayName,
          accountStatus: status,
          issuedAt: DateTime.now(),
        );
        _currentSession = restored;
        return Result.success(restored);
      }
    }

    return const Result.success(null);
  }

  @override
  Future<Result<void>> signOut() async {
    await _simulateDelay(150);
    _currentSession = null;
    _pendingOtpSessions.clear();
    if (_storage != null) {
      await _storage.delete('auth_user_id');
      await _storage.delete('auth_role');
      await _storage.delete('auth_phone');
      await _storage.delete('auth_status');
      await _storage.delete('auth_display_name');
    }
    return const Result.success(null);
  }

  @override
  Future<Result<AuthSession>> refreshSession() async {
    await _simulateDelay(100);
    final session = _currentSession;
    if (session == null) {
      return const Result.failure(
        UnauthorizedFailure('No active session to refresh.'),
      );
    }
    final refreshed = session.copyWith(issuedAt: DateTime.now());
    _currentSession = refreshed;
    return Result.success(refreshed);
  }

  // ---------------------------------------------------------------------------
  // Dev & Test helpers
  // ---------------------------------------------------------------------------

  Future<Result<AuthSession>> devSignInAsRole(UserRole role) async {
    final session = AuthSession(
      userId: 'dev_user_${role.storageKey}',
      phone: '+91 98765 XXXXX',
      role: role,
      displayName: 'Dev ${role.displayLabel}',
      accountStatus: AccountStatus.active,
      issuedAt: DateTime.now(),
    );
    _currentSession = session;
    await _persistSession(session);
    return Result.success(session);
  }

  Future<Result<AuthSession>> devSignInAsSuspended() async {
    final session = AuthSession(
      userId: 'dev_suspended_user',
      phone: '+91 98765 XXXXX',
      role: UserRole.customer,
      displayName: 'Suspended User',
      accountStatus: AccountStatus.suspended,
      issuedAt: DateTime.now(),
    );
    _currentSession = session;
    await _persistSession(session);
    return Result.success(session);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  AuthSession _buildMockSession(_MockOtpSession otpSession) {
    final raw = otpSession.phoneNumber;
    final maskedPhone = '+91 ${raw.substring(0, 5)} XXXXX';

    return AuthSession(
      userId:
          'mock_${otpSession.role.storageKey}_${DateTime.now().millisecondsSinceEpoch}',
      phone: maskedPhone,
      role: otpSession.role,
      displayName: otpSession.displayName,
      accountStatus: otpSession.accountStatus,
      issuedAt: DateTime.now(),
    );
  }

  Future<void> _persistSession(AuthSession session) async {
    if (_storage != null) {
      await _storage.write('auth_user_id', session.userId);
      await _storage.write('auth_role', session.role.storageKey);
      await _storage.write('auth_phone', session.phone);
      await _storage.write('auth_status', session.accountStatus.storageKey);
      if (session.displayName != null) {
        await _storage.write('auth_display_name', session.displayName!);
      }
    }
  }
}

class _MockOtpSession {
  final String phoneNumber;
  final UserRole role;
  final AccountStatus accountStatus;
  final String displayName;
  final String? customOtp;
  final DateTime expiresAt;

  const _MockOtpSession({
    required this.phoneNumber,
    required this.role,
    required this.accountStatus,
    required this.displayName,
    this.customOtp,
    required this.expiresAt,
  });
}
