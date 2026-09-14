/// User session representation in the domain layer.
class AuthSession {
  final String userId;
  final String phoneNumber;
  final String role;
  final String accessToken;
  final String refreshToken;
  final bool isProfileComplete;

  const AuthSession({
    required this.userId,
    required this.phoneNumber,
    required this.role,
    required this.accessToken,
    required this.refreshToken,
    required this.isProfileComplete,
  });
}
