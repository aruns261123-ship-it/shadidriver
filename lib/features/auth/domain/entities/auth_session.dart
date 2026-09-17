import 'account_status.dart';
import 'user_role.dart';

/// Immutable domain representation of the authenticated user's session.
///
/// Design invariants:
/// - No credential fields (access/refresh tokens) are stored here.
///   Tokens are managed exclusively by [SessionStorageService] and never
///   passed around as value objects.
/// - [phone] is the masked display phone (e.g., "+91 98765 XXXXX").
///   The unmasked value is never held in a domain entity.
/// - This entity is safe to hold in Riverpod state and pass to the UI.
final class AuthSession {
  final String userId;

  /// Display-safe phone representation.
  final String phone;

  final UserRole role;
  final String? displayName;
  final AccountStatus accountStatus;

  /// UTC timestamp when this session was issued, for display and staleness checks.
  final DateTime issuedAt;

  const AuthSession({
    required this.userId,
    required this.phone,
    required this.role,
    required this.accountStatus,
    this.displayName,
    required this.issuedAt,
  });

  /// Factory representing an unauthenticated, cleared session state.
  factory AuthSession.unauthenticated() => AuthSession(
        userId: '',
        phone: '',
        role: UserRole.customer,
        accountStatus: AccountStatus.suspended,
        issuedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  /// Whether this session represents an authenticated user.
  bool get isAuthenticated => userId.isNotEmpty;

  /// Whether the user's profile is considered complete enough for feature access.
  bool get isProfileComplete =>
      accountStatus != AccountStatus.profileIncomplete;

  /// Whether the account can access protected features.
  bool get canAccessFeatures => accountStatus.canAccessFeatures;

  AuthSession copyWith({
    String? userId,
    String? phone,
    UserRole? role,
    String? displayName,
    AccountStatus? accountStatus,
    DateTime? issuedAt,
  }) {
    return AuthSession(
      userId: userId ?? this.userId,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      accountStatus: accountStatus ?? this.accountStatus,
      issuedAt: issuedAt ?? this.issuedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuthSession &&
          other.userId == userId &&
          other.role == role &&
          other.accountStatus == accountStatus);

  @override
  int get hashCode => Object.hash(userId, role, accountStatus);

  @override
  String toString() =>
      'AuthSession(userId: $userId, role: ${role.displayLabel}, status: ${accountStatus.name})';
}
