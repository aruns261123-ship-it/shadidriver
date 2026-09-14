import '../../features/auth/domain/entities/auth_session.dart';

/// Domain-level interface for session persistence.
///
/// Separates the session-specific load/save/clear contract from the lower-level
/// [SecureStorageService] key-value interface. This lets auth code call
/// semantically meaningful methods rather than raw key lookups.
///
/// Tokens (access + refresh) are stored alongside the session fields but are
/// never surfaced through this interface's return types — they remain opaque
/// strings read only by the auth interceptor.
abstract interface class SessionStorageService {
  /// Persist the session to hardware-backed secure storage.
  ///
  /// Also persists the provided [accessToken] and [refreshToken] under their
  /// own storage keys. They are not part of [AuthSession] to avoid leaking
  /// credentials into Riverpod state.
  Future<void> saveSession({
    required AuthSession session,
    required String accessToken,
    required String refreshToken,
  });

  /// Load a previously persisted session.
  ///
  /// Returns `null` when no session exists (fresh install or after clear).
  /// Does NOT return tokens — those are read separately by the interceptor.
  Future<AuthSession?> loadSession();

  /// Clear all stored session data and tokens.
  Future<void> clearSession();

  /// Read the raw access token for use by the auth interceptor.
  ///
  /// Returns `null` if no token is stored.
  Future<String?> readAccessToken();

  /// Read the raw refresh token for use by the session refresh flow.
  ///
  /// Returns `null` if no token is stored.
  Future<String?> readRefreshToken();
}
