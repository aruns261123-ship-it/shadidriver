import '../../../../core/result/result.dart';
import '../entities/auth_session.dart';
import '../entities/user_role.dart';

/// Pure domain contract for all authentication operations.
///
/// Completely decoupled from any backend vendor (Firebase, Supabase, custom).
/// The mock implementation lives in the data layer and is swapped at the
/// provider level without touching any domain or presentation code.
abstract interface class AuthRepository {
  /// Request a one-time password for [phoneNumber] with the user's intended [role].
  ///
  /// Returns a [Result.success] containing an opaque session ID to be passed
  /// back to [verifyOtp]. Returns a [Result.failure] on network or server error.
  ///
  /// The OTP is delivered via SMS to the phone number and is NEVER returned
  /// or logged by the client.
  Future<Result<String>> requestOtp({
    required String phoneNumber,
    required UserRole role,
  });

  /// Verify an OTP code entered by the user.
  ///
  /// [otpSessionId] is the opaque ID returned by [requestOtp].
  /// [otpCode] is the 6-digit code entered by the user.
  ///
  /// On success: returns an [AuthSession] and the data layer internally
  /// persists the tokens to secure storage before resolving.
  /// On failure: returns a typed [AppFailure] (invalid OTP, expired, network, etc.)
  Future<Result<AuthSession>> verifyOtp({
    required String otpSessionId,
    required String otpCode,
  });

  /// Attempt to restore a previously authenticated session from secure storage.
  ///
  /// Returns [Result.success(null)] when no prior session exists (clean start).
  /// Returns [Result.success(session)] when tokens are valid and not expired.
  /// Returns [Result.failure] when tokens are corrupt, expired, or storage fails.
  Future<Result<AuthSession?>> restoreSession();

  /// Sign out the current user, clearing all tokens from secure storage.
  Future<Result<void>> signOut();

  /// Refresh the current access token using the stored refresh token.
  ///
  /// Called transparently by the auth interceptor on 401 responses.
  /// Returns the refreshed session or a failure (forcing re-login).
  Future<Result<AuthSession>> refreshSession();
}
