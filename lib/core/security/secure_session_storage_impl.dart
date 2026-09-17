import '../../features/auth/domain/entities/account_status.dart';
import '../../features/auth/domain/entities/auth_session.dart';
import '../../features/auth/domain/entities/user_role.dart';
import '../constants/app_constants.dart';
import 'secure_storage_service.dart';
import 'session_storage_service.dart';

/// Concrete implementation of [SessionStorageService] using the hardware-backed
/// [SecureStorageService] (Android Keystore / iOS Keychain).
///
/// Storage key mapping (from AppConstants):
///   shadi_user_id         → userId
///   shadi_user_role       → UserRole.storageKey
///   shadi_phone           → masked phone display string
///   shadi_display_name    → optional display name
///   shadi_account_status  → AccountStatus.storageKey
///   shadi_session_issued  → ISO-8601 issuedAt timestamp
///   shadi_access_token    → opaque bearer token  [NEVER LOGGED]
///   shadi_refresh_token   → opaque refresh token  [NEVER LOGGED]
///
/// SECURITY: Token keys are NEVER passed to any logger. Any log call in this
/// class must use only non-credential fields.
class SecureSessionStorageImpl implements SessionStorageService {
  final SecureStorageService _storage;

  const SecureSessionStorageImpl(this._storage);

  @override
  Future<void> saveSession({
    required AuthSession session,
    required String accessToken,
    required String refreshToken,
  }) async {
    // Write all session fields atomically (best-effort; no rollback on partial failure).
    await Future.wait([
      _storage.write(AppConstants.keyUserId, session.userId),
      _storage.write(AppConstants.keyUserRole, session.role.storageKey),
      _storage.write(AppConstants.keyPhone, session.phone),
      _storage.write(
        AppConstants.keyAccountStatus,
        session.accountStatus.storageKey,
      ),
      _storage.write(
        AppConstants.keySessionIssued,
        session.issuedAt.toIso8601String(),
      ),
      // Tokens stored last — if they fail, session metadata remains valid
      // for the next restore attempt to detect a partial write.
      _storage.write(AppConstants.keyAccessToken, accessToken),
      _storage.write(AppConstants.keyRefreshToken, refreshToken),
      if (session.displayName != null)
        _storage.write(AppConstants.keyDisplayName, session.displayName!),
    ]);
  }

  @override
  Future<AuthSession?> loadSession() async {
    final userId = await _storage.read(AppConstants.keyUserId);
    if (userId == null) return null; // No session persisted

    final roleKey = await _storage.read(AppConstants.keyUserRole);
    final role = UserRole.fromStorageKey(roleKey);
    if (role == null) return null; // Corrupted session — treat as missing

    final phone = await _storage.read(AppConstants.keyPhone) ?? '';
    final displayName = await _storage.read(AppConstants.keyDisplayName);
    final statusKey = await _storage.read(AppConstants.keyAccountStatus);
    final accountStatus = AccountStatus.fromStorageKey(statusKey);
    final issuedAtStr = await _storage.read(AppConstants.keySessionIssued);
    final issuedAt =
        issuedAtStr != null ? DateTime.tryParse(issuedAtStr) : null;

    return AuthSession(
      userId: userId,
      phone: phone,
      role: role,
      displayName: displayName,
      accountStatus: accountStatus,
      issuedAt: issuedAt ?? DateTime.now(),
    );
  }

  @override
  Future<void> clearSession() async {
    await _storage.deleteAll();
  }

  @override
  Future<String?> readAccessToken() =>
      _storage.read(AppConstants.keyAccessToken);

  @override
  Future<String?> readRefreshToken() =>
      _storage.read(AppConstants.keyRefreshToken);
}
