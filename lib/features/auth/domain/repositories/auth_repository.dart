import '../../../../core/result/result.dart';
import '../entities/auth_session.dart';

/// Pure Dart domain contract for authentication operations.
/// Completely decoupled from any specific vendor (Firebase, Supabase, or Custom backend).
abstract interface class AuthRepository {
  Future<Result<String>> requestPhoneOtp(String phoneNumber, String role);

  Future<Result<AuthSession>> verifyPhoneOtp({
    required String sessionId,
    required String otpCode,
    required String deviceId,
  });

  Future<Result<AuthSession>> getCurrentSession();

  Future<Result<void>> logout();

  Future<Result<AuthSession>> refreshSession();
}
