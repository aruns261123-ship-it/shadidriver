import '../../../../core/errors/failures.dart';
import 'auth_session.dart';

/// Sealed class hierarchy representing every possible authentication state.
///
/// UI code pattern-matches exhaustively on this type — no boolean flags,
/// no nullable session fields scattered across widgets.
sealed class AuthState {
  const AuthState();
}

/// Initial state before any session check has been performed.
/// Shown during app cold start (splash).
final class AuthUnknown extends AuthState {
  const AuthUnknown();
}

/// A transient state while an auth operation is in progress:
/// session restoration, OTP request, or OTP verification.
final class AuthLoading extends AuthState {
  final AuthLoadingReason reason;
  const AuthLoading({this.reason = AuthLoadingReason.restoringSession});
}

enum AuthLoadingReason {
  restoringSession,
  requestingOtp,
  creatingAccount,
  verifyingOtp,
  signingOut,
}

/// No active session. User must go through the authentication flow.
final class Unauthenticated extends AuthState {
  const Unauthenticated();
}

/// OTP has been sent; waiting for user to enter the code.
final class OtpSent extends AuthState {
  /// Phone number the OTP was sent to (for display only, already masked by server).
  final String maskedPhone;

  /// Opaque session identifier returned by the auth backend.
  /// Passed back verbatim on OTP verification — never interpreted client-side.
  final String otpSessionId;

  /// When the OTP expires (for countdown display).
  final DateTime expiresAt;

  const OtpSent({
    required this.maskedPhone,
    required this.otpSessionId,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// The user is fully authenticated and authorized.
final class Authenticated extends AuthState {
  final AuthSession session;
  const Authenticated(this.session);
}

/// An authentication operation failed.
final class AuthError extends AuthState {
  final AppFailure failure;
  final AuthErrorKind kind;

  const AuthError({required this.failure, this.kind = AuthErrorKind.generic});
}

/// Classifies the type of auth failure for targeted UI messaging.
enum AuthErrorKind {
  /// Generic / unclassified failure.
  generic,

  /// The OTP code entered is incorrect.
  invalidOtp,

  /// The OTP session has expired; user must request a new one.
  otpExpired,

  /// No network connection available.
  network,

  /// The backend returned an unexpected server error.
  server,

  /// The account has been suspended by an administrator.
  accountDisabled,
}
