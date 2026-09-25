import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers/app_providers.dart';
import '../../../../core/config/flavor.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/result/result.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../../data/auth_api_repository.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/auth_state.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/repositories/auth_repository.dart';

/// StateNotifier handling authentication lifecycle, OTP verification, and role sessions.
class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final SecureStorageService _secureStorage;
  final Ref _ref;

  AuthController(this._authRepository, this._secureStorage, this._ref)
    : super(const AuthUnknown());

  /// Restores session on app startup
  Future<void> restoreSession() async {
    state = const AuthLoading(reason: AuthLoadingReason.restoringSession);
    final result = await _authRepository.restoreSession();
    if (result.isSuccess && result.dataOrNull != null) {
      final session = result.dataOrNull!;
      _ref.read(activeSessionProvider.notifier).state = session;
      state = Authenticated(session);
    } else {
      state = const Unauthenticated();
    }
  }

  /// Request OTP for a phone number
  Future<Result<String>> requestOtp({
    required String phoneNumber,
    UserRole? role,
  }) async {
    state = const AuthLoading(reason: AuthLoadingReason.requestingOtp);
    final result = await _authRepository.requestOtp(
      phoneNumber: phoneNumber,
      role: role,
    );
    if (result.isSuccess) {
      final sessionId = result.dataOrNull!;
      final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
      final last4 = digits.length >= 4
          ? digits.substring(digits.length - 4)
          : digits;
      final masked = '+91 ••••• $last4';
      state = OtpSent(
        maskedPhone: masked,
        otpSessionId: sessionId,
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );
    } else {
      state = AuthError(
        failure:
            result.failureOrNull ??
            const UnknownFailure('Failed to request OTP. Please try again.'),
      );
    }
    return result;
  }

  /// Register a new account, then transition to [OtpSent] for verification.
  ///
  /// Mirrors [requestOtp]: on success the state machine lands in [OtpSent] so
  /// the same UI verification step can complete registration + login at once.
  Future<Result<String>> signUp({
    required String phoneNumber,
    required String displayName,
    UserRole role = UserRole.customer,
  }) async {
    state = const AuthLoading(reason: AuthLoadingReason.creatingAccount);
    final result = await _authRepository.signUp(
      phoneNumber: phoneNumber,
      displayName: displayName,
      role: role,
    );
    if (result.isSuccess) {
      final sessionId = result.dataOrNull!;
      final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
      final last4 = digits.length >= 4
          ? digits.substring(digits.length - 4)
          : digits;
      final masked = '+91 ••••• $last4';
      state = OtpSent(
        maskedPhone: masked,
        otpSessionId: sessionId,
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );
    } else {
      state = AuthError(
        failure:
            result.failureOrNull ??
            const UnknownFailure('Sign up failed. Please try again.'),
      );
    }
    return result;
  }

  /// Verify entered OTP code
  Future<Result<AuthSession>> verifyOtp({
    required String otpSessionId,
    required String otpCode,
  }) async {
    state = const AuthLoading(reason: AuthLoadingReason.verifyingOtp);
    final result = await _authRepository.verifyOtp(
      otpSessionId: otpSessionId,
      otpCode: otpCode,
    );
    if (result.isSuccess) {
      final session = result.dataOrNull!;
      _ref.read(activeSessionProvider.notifier).state = session;
      state = Authenticated(session);
    } else {
      final failure = result.failureOrNull;
      final kind = switch (failure?.code) {
        'OTP_EXPIRED' => AuthErrorKind.otpExpired,
        'INVALID_OTP' => AuthErrorKind.invalidOtp,
        'NETWORK_ERROR' => AuthErrorKind.network,
        'ACCOUNT_SUSPENDED' => AuthErrorKind.accountDisabled,
        _ => AuthErrorKind.invalidOtp,
      };
      state = AuthError(
        failure:
            failure ??
            const ValidationFailure(
              'The entered OTP is incorrect.',
              code: 'INVALID_OTP',
            ),
        kind: kind,
      );
    }
    return result;
  }

  /// Developer 1-tap role login — available in mock mode or development environment.
  Future<void> devLoginAsRole(UserRole role) async {
    final useMock = _ref
            .read(environmentConfigProvider.select((c) => c.useMockData));
    final flavor = _ref
            .read(environmentConfigProvider.select((c) => c.flavor));
    if (!useMock && flavor != AppFlavor.development) {
      state = const AuthError(
        failure: UnknownFailure(
          'Dev role login is only available in development environments.',
          'DEV_LOGIN_UNAVAILABLE',
        ),
      );
      return;
    }
    state = const AuthLoading(reason: AuthLoadingReason.verifyingOtp);

    final phone = useMock
        ? '9876543210'
        : switch (role) {
            UserRole.customer => '9810000001',
            UserRole.driver => '9810000002',
            UserRole.operationsAdmin => '98100000011',
            UserRole.verificationAdmin => '98100000012',
            UserRole.fleetOwner => '98100000013',
            _ => '9810000001',
          };

    final req = await _authRepository.requestOtp(
      phoneNumber: phone,
      role: role,
    );
    if (req.isSuccess) {
      String otp = '000000';
      if (_authRepository is AuthApiRepository) {
        otp = _authRepository.lastDebugOtpCode ?? '000000';
      } else {
        otp = switch (role) {
          UserRole.customer => '111111',
          UserRole.driver => '222222',
          UserRole.operationsAdmin => '444444',
          UserRole.verificationAdmin => '555555',
          UserRole.financeAdmin => '666666',
          UserRole.superAdmin => '999999',
          _ => '000000',
        };
      }
      final res = await _authRepository.verifyOtp(
        otpSessionId: req.dataOrNull!,
        otpCode: otp,
      );
      if (res.isSuccess) {
        final session = res.dataOrNull!;
        _ref.read(activeSessionProvider.notifier).state = session;
        state = Authenticated(session);
      } else {
        state = AuthError(
          failure:
              res.failureOrNull ?? const UnknownFailure('Dev login failed'),
        );
      }
    } else {
      state = AuthError(
        failure:
            req.failureOrNull ?? const UnknownFailure('Dev request failed'),
      );
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    state = const AuthLoading(reason: AuthLoadingReason.signingOut);
    await _authRepository.signOut();
    await _secureStorage.delete(AppConstants.keyAccessToken);
    await _secureStorage.delete(AppConstants.keyRefreshToken);
    _ref.read(activeSessionProvider.notifier).state =
        AuthSession.unauthenticated();
    state = const Unauthenticated();
  }

  /// Reset to phone input state
  void resetToPhoneInput() {
    state = const Unauthenticated();
  }
}

/// Provider for AuthController
final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    final authRepo = ref.watch(authRepositoryProvider);
    final storage = ref.watch(secureStorageProvider);
    return AuthController(authRepo, storage, ref);
  },
);
